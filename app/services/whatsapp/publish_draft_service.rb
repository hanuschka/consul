class Whatsapp::PublishDraftService < ApplicationService
  HARD_FAILED_STAGE = ProposalAiDraft::EvaluateTwoTierService::STAGE_HARD_FAILED
  ERROR_STAGE = ProposalAiDraft::EvaluateTwoTierService::STAGE_ERROR

  def initialize(conversation:)
    @conversation = conversation
  end

  # Returns the published proposal or budget investment, or a symbol naming what
  # stopped it: :criteria_failed when the phase's hard criteria reject the draft
  # — mirroring the web flow, which shows the evaluation result instead of
  # publishing — or :sentiment_missing when the phase requires a sentiment the
  # draft does not carry.
  def call
    resource = @conversation.draft_resource

    return if resource.blank?
    return resource if resource.published_at.present?
    return :sentiment_missing if sentiment_missing?(resource)

    stage = evaluation_stage(resource)

    return :criteria_failed if stage == HARD_FAILED_STAGE
    return if stage == ERROR_STAGE

    # Investments have no admin_accepted column, and the web budget flow
    # publishes them outright, so moderation stays a proposal concern.
    resource.admin_accepted = false if moderated? && resource.is_a?(Proposal)
    resource.draft = false
    resource.published_at = Time.current
    resource.save!(validate: false)

    resource
  end

  private

    def projekt_phase
      @conversation.projekt_phase
    end

    def moderated?
      projekt_phase.feature?("general.require_admin_acceptance")
    end

    # The last line of defence for a requirement nothing else on this path can
    # enforce: every write here is save!(validate: false), so Sentimentable's
    # create-time presence check never runs. The drafting flow asks for the
    # sentiment before the card, and this catches a draft that reached publish
    # without one anyway — a resumed draft from before the question existed,
    # or a phase that switched the feature on mid-flow.
    def sentiment_missing?(resource)
      Whatsapp::DraftSentiment.missing?(resource, projekt_phase)
    end

    # The evaluator swallows its own exceptions and answers with the error
    # stage, so a provider outage used to read as a pass and publish drafts the
    # phase's hard criteria had never actually approved. An unreachable
    # evaluation is now a reason not to publish yet, which the caller turns into
    # the retry prompt.
    def evaluation_stage(resource)
      return if !projekt_phase.user_resource_criteria.exists?

      stage = stored_stage(resource) || evaluate(resource)

      report_unavailable_evaluation(resource) if stage == ERROR_STAGE

      stage
    end

    # The draft card already evaluated this exact text: GenerateDraftService
    # clears the stored result whenever it rewrites the draft, so a verdict that
    # is present is about what the citizen just confirmed. Re-running it here
    # would be a second LLM call for the same answer.
    #
    # An error is not a verdict, so it is retried rather than reused — an
    # evaluator that was unreachable while drafting may well be reachable now.
    def evaluate(resource)
      ProposalAiDraft::EvaluateTwoTierService.call(resource: resource)["stage"]
    end

    def stored_stage(resource)
      stage = resource.ai_evaluation_result.to_h["stage"]

      return if stage.blank? || stage == ERROR_STAGE

      stage
    end

    def report_unavailable_evaluation(resource)
      Rails.logger.error(
        "[Whatsapp] criteria evaluation unavailable, not publishing " \
        "#{resource.class.name} #{resource.id}"
      )

      Sentry.capture_message(
        "Whatsapp publish blocked: criteria evaluation unavailable",
        extra: { whatsapp_conversation_id: @conversation.id, resource_id: resource.id }
      )
    end
end
