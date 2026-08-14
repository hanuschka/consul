class Whatsapp::ProcessInboundMessageJob < ApplicationJob
  queue_as :default

  CONTENDED_RETRY_DELAY = 5.seconds

  # Session-level advisory lock rather than a row lock: handling a message can
  # span a seconds-long LLM call, which has no business sitting inside an open
  # transaction. Postgres drops the lock by itself when the worker dies.
  LOCK_NAMESPACE = 8_724_301

  def perform(whatsapp_message_id, raw_message = {})
    whatsapp_message = Whatsapp::Message.find_by(id: whatsapp_message_id)

    return if whatsapp_message.blank?

    # Two messages from the same number are two independent jobs. Without this
    # they read-modify-write the same conversation step concurrently, which can
    # publish one draft twice.
    handled = hold_conversation(conversation_id_for(whatsapp_message)) do
      I18n.with_locale(::Whatsapp.locale_for(whatsapp_message.whatsapp_account)) do
        Whatsapp::Inbound::ProcessMessageService.call(whatsapp_message:, raw_message:)
      end
    end

    return if handled

    self.class.set(wait: CONTENDED_RETRY_DELAY).perform_later(whatsapp_message_id, raw_message)
  end

  private

    def conversation_id_for(whatsapp_message)
      whatsapp_message.whatsapp_account.conversation.id
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
end
