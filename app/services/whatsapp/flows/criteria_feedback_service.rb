class Whatsapp::Flows::CriteriaFeedbackService < Whatsapp::Flows::BaseService
  # The phase's hard criteria are the portal's own rules, not a safety filter,
  # so the citizen is told which one failed and left in the revision step with
  # the draft intact.
  #
  # Reached from the draft card now that the evaluation runs before the card
  # rather than at publish, and still from the publish path for a draft whose
  # evaluation could not be reused.
  def call
    @conversation.update!(step: "awaiting_revision")

    Whatsapp::Outbound.recovery(
      conversation: @conversation,
      body: body,
      actions: [:cancel]
    )
  end

  private

    def failed_criterion
      @conversation.draft_resource.ai_evaluation_result.to_h["failed_criterion"].to_h
    end

    def body
      criterion = failed_criterion

      I18n.t(
        "whatsapp.bot.criteria_failed",
        criterion: criterion["name"].to_s,
        feedback: criterion["feedback"].to_s
      )
    end
end
