class Whatsapp::Flows::AskIdeaService < Whatsapp::Flows::BaseService
  # Catalog C14. The permission check is repeated here rather than trusted from
  # whatever opened the flow: the tap that got here may be minutes or days old,
  # and a phase that closed in between must stop the idea before it costs a
  # draft.
  def self.handle_answer(conversation:, text:, inbound_message_id: nil)
    new(conversation: conversation).handle_answer(text, inbound_message_id)
  end

  def call
    if projekt_phase.blank?
      return Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.no_projekt")
      )
    end

    return if refuse_if_not_permitted

    # The consent gate, and it sits here rather than at any of the six callers
    # because this is the one method all of them reach: the phase pill, the
    # assistant's two tools, the QR entry token, the resume path and the
    # duplicate offer. Below the permission check on purpose — a closed phase is
    # refused before the citizen is asked to accept anything for it.
    return Whatsapp::Flows::TermsConsentService.before_idea(conversation: @conversation) if
      !account.terms_accepted?

    @conversation.update!(step: Whatsapp::Conversation::Step::AWAITING_IDEA)

    Whatsapp::Send.text(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.proposal.ask_idea")
    )
  end

  # The message that answers the question. An empty one — a sticker, a
  # transcription that came back blank — is asked again rather than handed to
  # the drafting call.
  def handle_answer(text, inbound_message_id)
    idea_text = text.to_s.strip

    if idea_text.blank?
      return Whatsapp::Send.recovery(
        conversation: @conversation,
        body: Whatsapp.phrase("whatsapp.bot.idea_missing"),
        actions: [:cancel]
      )
    end

    Whatsapp::Flows::BuildDraftService.from_idea(
      conversation: @conversation, idea_text: idea_text,
      inbound_message_id: inbound_message_id
    )
  end

  private

    def projekt_phase
      @conversation.projekt_phase
    end
end
