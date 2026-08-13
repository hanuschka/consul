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

    # Not Outbound.recovery: that renders recovery pills only, and the way out
    # of a failed criterion is the flow's own revise action rather than a retry.
    Whatsapp::Outbound.question(
      conversation: @conversation,
      body: body,
      buttons: Whatsapp::FlowActions.revise_decision_buttons
    )
  end

  private

    def failed_criterion
      @conversation.draft_resource.ai_evaluation_result.to_h["failed_criterion"].to_h
    end

    def body
      criterion = failed_criterion

      Whatsapp.phrase("whatsapp.bot.criteria_failed", criterion: criterion["name"].to_s,
        feedback: citizen_feedback(criterion["feedback"].to_s))
    end

    # Said back to the citizen in their own terms rather than about a Beitrag
    # that may not exist yet. The idea text is what they last wrote — on a
    # revision, everything they have written so far.
    def citizen_feedback(feedback)
      Whatsapp::AiAssistant::CriterionFeedbackService.call(
        criterion_feedback: feedback,
        idea_text: @conversation.context["last_idea_text"].to_s
      )
    end
end
