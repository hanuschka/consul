class Whatsapp::AiAssistant::ContinueConversationService < ApplicationService
  # The one way a finished action hands back into the conversation, and the only place
  # that knows how to ask the assistant something no citizen wrote. Answers whether it
  # carried on: false is the caller's signal to send its own closing line, which is why
  # every caller keeps one.
  #
  # A note rather than an instruction to send fixed copy: the assistant is handed the
  # fact that something completed and writes the confirmation and what follows it itself,
  # which is what makes the wording fresh, the address form the configured one and the
  # language the citizen's own. The fixed lines it replaces were locale copy translated
  # after the fact, so this path has one hop fewer rather than one more.
  #
  # ── Why a turn cannot start inside a turn ───────────────────────────────────
  # Some completions are reached from a tool the assistant itself called — a ballot
  # begun through start_poll_vote with every question already answered. A second turn
  # there would ask the model about a reply it is in the middle of writing, on a chat
  # state that has not been persisted yet, while holding the conversation's advisory
  # lock and the tool-call budget of the turn it is nested in. Refused, and the caller's
  # own line goes out instead — which is exactly what the citizen got before this
  # existed, so the in-turn path is unchanged rather than degraded.
  def initialize(conversation:, note:)
    @conversation = conversation
    @note = note
  end

  def call
    return false if @note.blank?
    return false if !::Ai::Settings.ai_available?
    return false if ::Current.whatsapp_assistant_turn_running
    return false if typing_message_id.blank?

    ::Whatsapp::AiAssistant::RouterService.call(
      conversation: @conversation,
      inbound_text: @note,
      typing_message_id: typing_message_id,
      previous_inbound_at: @conversation.last_inbound_at
    ).success?
  end

  private

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
