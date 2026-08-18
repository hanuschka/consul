class Whatsapp::Inbound::ProcessMessageService < ApplicationService
  # The one keyword list left. Every other typed message is read by a model,
  # but a typed opt-out word must end messages whether or not a provider is
  # reachable — an outage that keeps broadcasting to a number that asked us to
  # stop is the failure nothing may allow.
  OPT_OUT_KEYWORDS = ["stop", "stopp", "abmelden", "unsubscribe"].freeze

  def initialize(whatsapp_message:, raw_message: {})
    @whatsapp_message = whatsapp_message
    @raw_message = raw_message || {}
  end

  # THE GATE CHAIN — ordering is the contract. Each gate is one named call
  # into a collaborator or a short method below; the invariants that pin each
  # gate to its slot:
  #
  # - The typed STOP word is read before any model is asked: an outage that
  #   keeps broadcasting to a number that asked us to stop is the failure
  #   nothing may allow.
  # - pending_question is consumed before any gate can return early, so no
  #   branch can leave it set and turn an "abbrechen" days later into a
  #   cancellation.
  # - A voice note is transcribed just ahead of the keyword gate — the first
  #   text consumer. The "could not read it" reply goes out there, but the
  #   chain runs on: a first contact still gets the greeting after it.
  # - The channel intents (opt-out, opt-in, abort) come after STOP but before
  #   the opted-out return, because opting back in must be readable from an
  #   opted-out number. Never for a tapped pill, whose label the citizen did
  #   not write.
  # - Recovery pills before catalog pills: both are tap ids, built by
  #   different modules from different prefixes, and both must be read before
  #   any step can mistake a tapped button for idea text.
  # - A text-less voice note halts only after the tap gates — a tap is never
  #   audio — and everything below needs text.
  # - Entry tokens are captured before the staleness gate: start_flow!
  #   restarts the flow clock, so a fresh scan is never interrupted by a
  #   resume question.
  # - There is no unlinked gate. There was one, and it answered every message
  #   from a number with no account with the linking question, before the
  #   citizen could say what they wanted. An account is asked for by whichever
  #   action turns out to need one — FlowActionDispatch for a pill,
  #   RefuseParticipationService for a phase — so browsing and guest
  #   participation reach their own answers instead (CON-2971).
  # - Staleness before the assistant: the resume question is asked once, and
  #   the question itself moves the step.
  # - The fresh start sits between the assistant and the step dispatch, and
  #   nowhere else: it acts on the verdict of the one reading this message
  #   already got, which for a linked citizen is only decided once the router
  #   has run — and it has to be read before the step can take the message as
  #   the thing it was waiting for.
  # - The assistant sees only what the protocol gates left — never taps,
  #   never location pins, never guests — and its one reading travels on the
  #   routing object into the step dispatch instead of being re-derived by a
  #   second completion.
  def call
    return if !::Whatsapp.enabled?

    conversation.update!(last_inbound_at: latest_inbound_at)

    open_message_context

    consume_pending_question
    announce_unreadable_voice_note

    return if handle_stop_keywords
    return if handle_message_intent
    return if account.opt_out_at.present?
    return Whatsapp::Flows::OnboardingGreetingService.first_contact(conversation:) if first_contact?

    # The disclosure heads the citizen's first message, so it is sent before
    # anything below can reply. Once per number rather than once per 24-hour
    # window: a regular who reads it every day stops reading it at all. A first
    # contact is the exception, its own opening message already carries it.
    Whatsapp::Flows::OnboardingGreetingService.disclose(conversation:) if !account.ai_disclosed?

    return if handle_recovery_action
    return if handle_flow_action
    return if reading.unreadable_voice_note?

    entry = capture_entry_token

    return handle_entry(entry) if entry.present?
    return if handle_stale_flow
    return if routed_by_assistant?
    return if handle_fresh_start

    dispatch_step
  end

  private

    # What the bot's own copy is written for. Everything below that says a
    # sentence reaches it through Whatsapp.phrase, which rewrites the locale
    # line for the message being answered when a context is open — so it is
    # opened once here, for the whole turn, rather than passed down through
    # every flow service.
    #
    # Set before any gate can reply, including the first-contact greeting: a
    # citizen's opening message is exactly the one worth answering in its own
    # terms. Nothing outside this path opens one, which is what keeps the
    # broadcast jobs on their approved wording.
    def open_message_context
      Current.whatsapp_message_context = Whatsapp::AiAssistant::MessageContext.new(
        conversation: conversation, inbound_text: reading.text
      )
    end

    # The one model reading of this message, shared between the channel gate,
    # the router gate, and the step dispatch (see AssistantRouting).
    def routing
      @routing ||= Whatsapp::Inbound::AssistantRouting.new(
        conversation: conversation, account: account, reading: reading,
        pending_question: pending_question?
      )
    end

    def routed_by_assistant?
      routing.handled?
    end

    # The one reading of the inbound payload, shared with every collaborator
    # so nothing re-digs raw_message or re-transcribes a voice note.
    def reading
      @reading ||= Whatsapp::Inbound::MessageReading.new(
        whatsapp_message: @whatsapp_message, raw_message: @raw_message
      )
    end

    # The transcription-failure reply's position is load-bearing: whoever
    # reads text first decides who receives it, and the stop-keyword gate
    # below is the first text consumer on every path. The reply goes out
    # here, but the chain runs on — a first contact still gets the greeting
    # after it, and only the text-less-audio gate further down halts.
    def announce_unreadable_voice_note
      return if !reading.unreadable_voice_note?

      Whatsapp::Send.recovery(
        conversation: conversation,
        body: Whatsapp.phrase("whatsapp.bot.transcription_failed"),
        actions: [:cancel]
      )
    end

    def tapped_reply_id
      reading.tapped_reply_id
    end

    def first_contact?
      return true if @whatsapp_message.welcome? && !account.greeted?

      account.user_id.blank? && !account.greeted?
    end

    # Only ever forwards: a retried or out-of-order delivery must not rewind the
    # conversation's clock.
    def latest_inbound_at
      [@whatsapp_message.sent_at || Time.current, conversation.last_inbound_at].compact.max
    end

    def account
      @account ||= @whatsapp_message.whatsapp_account
    end

    def conversation
      @conversation ||= account.conversation
    end

    # The catalog uses one word for two things: "Stop" abandons what is in
    # progress (C21), and "STOP" ends all messages for good (E34). Decided here
    # rather than inside either service — getting it wrong means a citizen who
    # wanted to cancel is silently unsubscribed instead.
    def handle_stop_keywords
      return false if !OPT_OUT_KEYWORDS.include?(normalized_text)

      if conversation.drafting?
        Whatsapp::Flows::CancelService.call(conversation:)
      else
        Whatsapp::Flows::MessageDeliveryService.disable(conversation:)
      end

      true
    end

    # The channel-level requests — leaving the channel, coming back to it,
    # abandoning what is in progress — decided by this message's one model
    # reading. Anyone still on the channel is read by the router, which carries
    # stop_messages and abort_submission as tools, so the classifier is never
    # asked as well; it answers for an opted-out number, whose one open
    # question is whether it is opting back in.
    #
    # Never for a tapped pill, whose label the citizen did not write: those are
    # routed by their ids two gates below. A verdict the account's state rules
    # out is dropped rather than acted on — the model is told the state, but
    # what it answers is still only a reading.
    def handle_message_intent
      return false if tapped_reply_id.present?
      return false if !routing.classifier_routes?

      case routing.message_intent.verdict
      when :opt_out
        return false if account.opt_out_at.present?

        Whatsapp::Flows::MessageDeliveryService.disable(conversation:)
      when :opt_in
        return false if account.opt_out_at.blank?

        Whatsapp::Flows::MessageDeliveryService.enable(conversation:)
      when :abort
        return false if !routing.interaction_open?

        Whatsapp::Flows::CancelService.call(conversation:)
      else
        return false
      end

      true
    end

    def pending_question?
      @pending_question
    end

    # Consumed before any gate below can return early, so no branch can leave
    # the flag set and turn an "abbrechen" days later into a cancellation.
    def consume_pending_question
      @pending_question = conversation.consume_pending_question!
    end

    # Handled ahead of the step dispatcher: a tapped recovery button must not be
    # read as idea text by whichever step happens to be active.
    def handle_recovery_action
      Whatsapp::Inbound::RecoveryActionDispatch.new(
        conversation: conversation, reading: reading
      ).call
    end

    # Every catalog pill, with its account gating, in one collaborator.
    def handle_flow_action
      Whatsapp::Inbound::FlowActionDispatch.new(
        conversation: conversation, account: account, reading: reading
      ).call
    end

    # A phase QR code names the phase, so the citizen has already chosen and is
    # asked for their idea. A projekt QR code with one open phase has chosen only
    # the projekt: they get its card first, because the phase is this bot's
    # inference and not their decision.
    def handle_entry(entry)
      return Whatsapp::Flows::RefuseParticipationService.call(conversation:, reason: :no_open_phase) if
        entry == :projekt_without_phase
      return Whatsapp::Flows::DiscoveryService.linked(conversation:, projekt: entry_projekt) if
        entry == :projekt_choice

      return Whatsapp::Flows::ProposalPromptService.call(
        conversation:, projekt_phase: conversation.projekt_phase
      ) if entry == :projekt

      Whatsapp::Flows::AskIdeaService.call(conversation:)
    end

    # A draft older than Conversation::STALE_FLOW_AFTER is not resumed silently.
    # Only asked once — the question itself moves the step, so the next message
    # is an answer to it rather than a second asking.
    def handle_stale_flow
      return false if !conversation.drafting?
      return false if conversation.awaiting_resume_decision?
      return false if !conversation.stale_flow?

      Whatsapp::Flows::ResumeOrRestartService.call(conversation:)

      true
    end

    # A message with no substance of its own, while the bot is waiting on free
    # text, is the citizen beginning again rather than the answer to the step
    # — "hallo" at the idea step used to become the text of a contribution,
    # draft generation and all (CON-2968). They are asked which they meant.
    #
    # Only the classifier's verdict reaches here. A linked citizen's reading is
    # the router's, and there the same decision is a tool that has already
    # asked the question and halted the turn, so this gate never sees it.
    def handle_fresh_start
      return false if !Whatsapp::Conversation::FRESH_START_STEPS.include?(conversation.step)
      return false if routing.verdict != :fresh_start

      Whatsapp::Flows::ContinueOrRestartService.ask(conversation:)

      true
    end

    def dispatch_step
      Whatsapp::Inbound::StepDispatch.new(
        conversation: conversation, reading: reading, routing: routing
      ).call
    end

    # Held as an instance so handle_entry can read the captured projekt after
    # the capture ran (see EntryTokenCapture).
    def entry_capture
      @entry_capture ||= Whatsapp::Inbound::EntryTokenCapture.new(
        conversation: conversation, reading: reading
      )
    end

    def capture_entry_token
      entry_capture.call
    end

    def entry_projekt
      entry_capture.projekt
    end

    def normalized_text
      reading.normalized_text
    end
end
