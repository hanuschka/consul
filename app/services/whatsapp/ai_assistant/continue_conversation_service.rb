class Whatsapp::AiAssistant::ContinueConversationService < ApplicationService
  # The one way a finished action hands back into the conversation, and the only place
  # that knows how to ask the assistant something no citizen wrote.
  #
  # A note rather than an instruction to send fixed copy: the assistant is handed the
  # fact that something completed and writes the confirmation and what follows it itself,
  # which is what makes the wording fresh, the address form the configured one and the
  # language the citizen's own. The fixed lines it replaces were locale copy translated
  # after the fact, so this path has one hop fewer rather than one more.
  #
  # ── The three answers, and why they are not two ─────────────────────────────
  # CARRIED_ON is the citizen answered. UNAVAILABLE is nobody is going to answer them
  # unless the caller does, which is why every caller keeps its closing line. IN_TURN is
  # neither: an answer is already being written, and the caller's line would land beside
  # it rather than instead of it.
  #
  # A turn cannot start inside a turn. Some completions are reached from a tool the
  # assistant itself called — a ballot begun through start_poll_vote with every question
  # already answered — and a second turn there would ask the model about a reply it is
  # in the middle of writing, on a chat state that has not been persisted yet, while
  # holding the conversation's advisory lock and the tool-call budget of the turn it is
  # nested in. The tool that reached this is what says so instead: it has the model's
  # attention already, so it reports the completion as its result and the reply the
  # citizen reads is that turn's.
  #
  # Which means IN_TURN is only right for a caller reached from a tool that reports it.
  # There is one — Whatsapp::Polls::OfferBallotService, through start_poll_vote — and a
  # second in-turn caller that swallowed the outcome would be a completed action nobody
  # confirmed.
  CARRIED_ON = :carried_on
  IN_TURN = :in_turn
  UNAVAILABLE = :unavailable

  def initialize(conversation:, note:)
    @conversation = conversation
    @note = note
  end

  def call
    return IN_TURN if ::Current.whatsapp_assistant_turn_running
    return UNAVAILABLE if @note.blank?
    return UNAVAILABLE if !::Ai::Settings.ai_available?
    return UNAVAILABLE if typing_message_id.blank?

    return CARRIED_ON if turn.success?

    UNAVAILABLE
  end

  private

    def turn
      ::Whatsapp::AiAssistant::RouterService.call(
        conversation: @conversation,
        inbound_text: @note,
        typing_message_id: typing_message_id,
        previous_inbound_at: @conversation.last_inbound_at
      )
    end

    # The message the citizen is sitting under, which for a completion is always the last
    # thing they sent: the tap that finished the vote, or — where the linking was
    # confirmed in a browser and no message finished anything — whatever they wrote
    # before they went to follow the link.
    #
    # Read from the record rather than passed down. A completion is reached through two
    # or three services that have no business carrying a protocol id, and the inbound
    # message is persisted before any of them runs, so the store already answers it.
    #
    # No anchor means no citizen has ever written to this number, and a bubble is the
    # smaller half of what is missing: there is also no dialog to continue, so the
    # caller's own line is the whole of what can be said.
    def typing_message_id
      return @typing_message_id if defined?(@typing_message_id)

      @typing_message_id = ::Whatsapp::Message.latest_inbound_id(
        account: @conversation.whatsapp_account
      )
    end
end
