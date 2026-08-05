class Whatsapp::ProposalPermissionService < ApplicationService
  def initialize(projekt_phase:, user:)
    @projekt_phase = projekt_phase
    @user = user
  end

  def call
    return :phase_missing if @projekt_phase.blank?
    return :not_logged_in if @user.blank?
    return :phase_not_proposal if !@projekt_phase.is_a?(ProjektPhase::ProposalPhase)
    return :creation_disabled if !@projekt_phase.feature?("resource.users_can_create_proposals")
    return :ai_flow_disabled if !@projekt_phase.feature?("resource.create_proposal_with_ai")

    @projekt_phase.permission_problem(@user, location: :whatsapp_bot)
  end
end
