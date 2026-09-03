class Whatsapp::ProcessInboundMessageJob < ApplicationJob
  queue_as :default
  queue_with_priority ::Whatsapp::REPLY_PRIORITY

  CONTENDED_RETRY_DELAY = 5.seconds

  # How long a message waits for its conversation before it is answered out of
  # the deterministic flow instead. A turn legitimately holds the lock for a
  # while — the tool loop's requests are sequential and each carries its own
  # timeout — so this is generous. What it ends is the case it used to handle
  # silently: requeueing every five seconds forever behind a holder that is
  # never going to let go, with every spin a job of its own competing for the
  # same workers as the reply it is waiting for.
  MAX_CONTENDED_ATTEMPTS = 24

  # Session-level advisory lock rather than a row lock: handling a message can
  # span a seconds-long LLM call, which has no business sitting inside an open
  # transaction. Postgres drops the lock by itself when the worker dies.
  LOCK_NAMESPACE = 8_724_301

  # The attempt counter is a third positional argument with a default, so the
  # jobs already enqueued when this shipped deserialise and run as attempt zero.
  def perform(whatsapp_message_id, raw_message = {}, contended_attempts = 0)
    whatsapp_message = Whatsapp::Message.find_by(id: whatsapp_message_id)

    return if whatsapp_message.blank?

    account = whatsapp_message.whatsapp_account

    I18n.with_locale(::Whatsapp.locale_for(account)) do
      dispatch(
        whatsapp_message: whatsapp_message,
        raw_message: raw_message,
        conversation: account.conversation,
        contended_attempts: contended_attempts
      )
    end
  end

  private

    # Two messages from the same number are two independent jobs. Without the
    # lock they read-modify-write the same conversation step concurrently, which
    # can publish one draft twice.
    def dispatch(whatsapp_message:, raw_message:, conversation:, contended_attempts:)
      handled = hold_conversation(conversation.id) do
        answer(whatsapp_message, raw_message, conversation)
      end

      return if handled
      return give_up_on_contention(conversation) if out_of_attempts?(contended_attempts)

      self.class
        .set(wait: CONTENDED_RETRY_DELAY)
        .perform_later(whatsapp_message.id, raw_message, contended_attempts + 1)
    end

    def out_of_attempts?(contended_attempts)
      contended_attempts >= MAX_CONTENDED_ATTEMPTS
    end

    # The failure that used to end in silence. Delayed Job gives up after three
    # attempts and the inbound dedup already suppresses 360dialog's
    # redeliveries, so an exception here was a message nothing would ever answer
    # — raised while the citizen is watching a typing bubble.
    #
    # Deliberately not re-raised, so nothing retries it: the line below carries
    # the retry pill, and running the same code over the same message is what
    # produced the failure in the first place. Asking the citizen is the only
    # retry with new information in it.
    def answer(whatsapp_message, raw_message, conversation)
      Whatsapp::Inbound::ProcessMessageService.call(
        whatsapp_message: whatsapp_message, raw_message: raw_message
      )
    rescue StandardError => e
      report(e, conversation)

      say_it_could_not_be_answered(conversation)
    end

    # Two minutes behind a turn that has still not finished. Answered rather
    # than dropped: whatever holds the lock is not going to reply to *this*
    # message, and a message that produces nothing at all reads as a bot that
    # has stopped working — so the citizen taps and writes again, which is one
    # more job on the queue that is already the problem.
    def give_up_on_contention(conversation)
      report_contention(conversation)

      say_it_could_not_be_answered(conversation)
    end

    # The deterministic line, sent from here rather than through the inbound
    # chain because this can run without the lock the state writers need:
    # recovery_without_assistant records no confirmations and stores no retry
    # snapshot, so it touches nothing. Without a snapshot the retry pill falls
    # through to the assistant, which is where "again" is understood anyway.
    #
    # Its own rescue, because it is the last thing standing between a failure
    # and silence: a send that raises here must not take the report with it.
    def say_it_could_not_be_answered(conversation)
      ::Whatsapp::Send.recovery_without_assistant(
        conversation: conversation,
        body: I18n.t("whatsapp.bot.assistant_unavailable_retryable"),
        actions: %i[retry cancel]
      )
    rescue StandardError => e
      report(e, conversation)
    end

    # Runs the block only when no other worker holds the conversation. Returns
    # false when the lock was busy, so the job can requeue instead of racing.
    def hold_conversation(conversation_id)
      return false if !acquire_lock(conversation_id)

      begin
        yield
      ensure
        release_lock(conversation_id)
      end

      true
    end

    def acquire_lock(conversation_id)
      connection.select_value(lock_statement("pg_try_advisory_lock", conversation_id))
    end

    def release_lock(conversation_id)
      connection.select_value(lock_statement("pg_advisory_unlock", conversation_id))
    end

    def connection
      ActiveRecord::Base.connection
    end

    def lock_statement(function, conversation_id)
      ActiveRecord::Base.sanitize_sql_array(
        ["SELECT #{function}(?, ?)", LOCK_NAMESPACE, conversation_id]
      )
    end

    def report(exception, conversation)
      Rails.logger.error(
        "[Whatsapp] inbound message could not be answered: " \
        "#{exception.class} - #{exception.message}"
      )

      Sentry.capture_exception(exception, extra: { whatsapp_conversation_id: conversation.id })
    end

    # A message rather than an exception: nothing went wrong here, and the
    # stacktrace would be this job's own loop rather than whatever is holding
    # the lock. Its own fingerprint so a stuck worker is one issue to watch,
    # not one issue per conversation that queued behind it.
    def report_contention(conversation)
      held_for = (MAX_CONTENDED_ATTEMPTS * CONTENDED_RETRY_DELAY).to_i

      Rails.logger.error(
        "[Whatsapp] conversation #{conversation.id} stayed locked for #{held_for} seconds"
      )

      Sentry.capture_message(
        "WhatsApp conversation lock never released",
        level: :error,
        fingerprint: ["whatsapp-conversation-lock"],
        extra: { whatsapp_conversation_id: conversation.id, waited_seconds: held_for }
      )
    end
end
