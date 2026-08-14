class Whatsapp::Flows::CriteriaFeedbackService < Whatsapp::Flows::BaseService
  # The phase's hard criteria are the portal's own rules, not a safety filter,
  # so the citizen is told which one failed and left in the revision step with
  # the draft intact.
  #
  # Reached from the draft card now that the evaluation runs before the card
  # rather than at publish, and still from the publish path for a draft whose
  # evaluation could not be reused.
  def call
    @conversation.update!(step: Whatsapp::Conversation::Step::AWAITING_REVISION)

    # Not Send.recovery: that renders recovery pills only, and the way out
    # of a failed criterion is the flow's own revise action rather than a retry.
    Whatsapp::Send.question(
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
        feedback: citizen_feedback(criterion))
    end

    # Said back to the citizen in their own terms rather than about a Beitrag
    # that may not exist yet. The wording rode the evaluation call itself —
    # see EvaluateTwoTierService — so nothing is paid for here; an
    # evaluation stored before the field existed falls back to the
    # evaluator's own line, relabelled.
    def citizen_feedback(criterion)
      criterion["citizen_feedback"].presence ||
        relabelled_feedback(criterion["feedback"].to_s)
    end

    # The evaluator calls the thing a "Vorschlag" and the message this line
    # goes into calls it a "Beitrag" two lines above, which reads as two
    # different words for the same submission. Fallback path only: the
    # evaluator prompt is shared with the web flows, so it cannot be reworded
    # at the source.
    def relabelled_feedback(feedback)
      return feedback if resource_nouns.blank?

      feedback.gsub(resource_noun_pattern, resource_nouns)
    end

    # Read from the locale rather than written here: which word a portal uses
    # for a submission is the same decision the rest of the copy makes, and a
    # German-only hash in Ruby leaves every other locale unrelabelled.
    def resource_nouns
      @resource_nouns ||=
        I18n.t("whatsapp.bot.resource_nouns", default: {}).transform_keys(&:to_s)
    end

    # Longest form first, so a plural is matched before the singular it
    # contains and the order the locale file happens to list them in never
    # starts mattering.
    def resource_noun_pattern
      Regexp.union(resource_nouns.keys.sort_by { |noun| -noun.length })
    end
end
