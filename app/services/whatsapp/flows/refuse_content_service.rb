class Whatsapp::Flows::RefuseContentService < Whatsapp::Flows::BaseService
  # What the citizen is told when the safety check refuses their text. Held
  # apart from RefuseParticipationService, which answers a different question:
  # that one is about who may take part, this one about what may be published,
  # and only this one leaves the flow open.
  #
  # The step goes back to the idea question rather than ending the submission.
  # Most of what lands here is one sentence too far in an otherwise real
  # complaint, and a citizen who rewrites it should not have to find their way
  # back into the projekt they had already chosen.
  def initialize(conversation:, reason:)
    super(conversation: conversation)
    @reason = reason.to_s
  end

  def call
    @conversation.update!(step: "awaiting_idea")

    Whatsapp::Outbound.recovery(conversation: @conversation, body: body, actions: [:cancel])
  end

  private

    # The reason is named, but never quoted back: repeating the sentence that
    # was refused would put it in the chat a second time, and the citizen wrote
    # it and knows what it said.
    def body
      [
        I18n.t("whatsapp.bot.refused_content.intro"),
        I18n.t("whatsapp.bot.refused_content.reasons.#{reason_key}"),
        I18n.t("whatsapp.bot.refused_content.retry_hint")
      ].join("\n\n")
    end

    def reason_key
      return @reason if ::ProposalAiDraft::EvaluateContentSafetyService::REASONS.include?(@reason)

      ::ProposalAiDraft::EvaluateContentSafetyService::REASONS.first
    end
end
