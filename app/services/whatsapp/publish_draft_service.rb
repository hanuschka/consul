class Whatsapp::PublishDraftService < ApplicationService
  HARD_FAILED_STAGE = ProposalAiDraft::EvaluateTwoTierService::STAGE_HARD_FAILED

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
    return :criteria_failed if criteria_failed?(resource)

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

    def criteria_failed?(resource)
      return false if !projekt_phase.user_resource_criteria.exists?

      result = ProposalAiDraft::EvaluateTwoTierService.call(resource: resource)

      result["stage"] == HARD_FAILED_STAGE
    end
end
