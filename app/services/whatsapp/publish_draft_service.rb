class Whatsapp::PublishDraftService < ApplicationService
  HARD_FAILED_STAGE = ProposalAiDraft::EvaluateTwoTierService::STAGE_HARD_FAILED
  ERROR_STAGE = ProposalAiDraft::EvaluateTwoTierService::STAGE_ERROR

  def initialize(conversation:)
    @conversation = conversation
  end

  # Returns the published proposal or budget investment, or the symbol
  # :criteria_failed when the phase's hard criteria reject the draft — mirroring
  # the web flow, which shows the evaluation result instead of publishing.
  def call
    resource = @conversation.draft_resource

    return if resource.blank?
    return resource if resource.published_at.present?

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

    # The evaluator swallows its own exceptions and answers with the error
    # stage, so a provider outage used to read as a pass and publish drafts the
    # phase's hard criteria had never actually approved. An unreachable
    # evaluation is now a reason not to publish yet, which the caller turns into
    # the retry prompt.
    def evaluation_stage(resource)
      return if !projekt_phase.user_resource_criteria.exists?

      stage = ProposalAiDraft::EvaluateTwoTierService.call(resource: resource)["stage"]

      report_unavailable_evaluation(resource) if stage == ERROR_STAGE

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
