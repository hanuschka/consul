class Whatsapp::PublishProposalService < ApplicationService
  HARD_FAILED_STAGE = ProposalAiDraft::EvaluateTwoTierService::STAGE_HARD_FAILED

  def initialize(conversation:)
    @conversation = conversation
  end

  # Returns the published proposal, or the symbol :criteria_failed when the
  # phase's hard criteria reject the draft — mirroring the web flow, which shows
  # the evaluation result instead of publishing.
  def call
    proposal = @conversation.proposal

    return if proposal.blank?
    return :criteria_failed if criteria_failed?(proposal)

    proposal.admin_accepted = false if moderated?
    proposal.draft = false
    proposal.published_at = Time.current
    proposal.save!(validate: false)

    proposal
  end

  private

    def projekt_phase
      @conversation.projekt_phase
    end

    def moderated?
      projekt_phase.feature?("general.require_admin_acceptance")
    end

    def criteria_failed?(proposal)
      return false if !projekt_phase.user_resource_criteria.exists?

      result = ProposalAiDraft::EvaluateTwoTierService.call(resource: proposal)

      result["stage"] == HARD_FAILED_STAGE
    end
end
