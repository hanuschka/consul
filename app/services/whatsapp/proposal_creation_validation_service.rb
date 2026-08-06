class Whatsapp::ProposalCreationValidationService < ApplicationService
  def initialize(projekt_phase:, user:)
    @projekt_phase = projekt_phase
    @user = user
  end

  def call
    return :phase_missing if @projekt_phase.blank?
    return :not_logged_in if @user.blank?
    return :phase_not_supported if feature_keys.blank?
    return :creation_disabled if !@projekt_phase.feature?(feature_keys[:creation])
    return :ai_flow_disabled if !@projekt_phase.feature?(feature_keys[:ai_flow])
    return :budget_heading_missing if budget_heading_missing?

    @projekt_phase.permission_problem(@user, location: :whatsapp_bot)
  end

  private

    # Which flags apply depends on the phase type, and a type absent from the
    # map is one the bot has no flow for.
    def feature_keys
      WhatsappEligiblePhasesQuery.feature_keys_for(@projekt_phase)
    end

    # An investment cannot be built without the budget's heading, and a budget
    # here has exactly one (Budget has_one :heading, through: :group).
    def budget_heading_missing?
      return false if !@projekt_phase.is_a?(ProjektPhase::BudgetPhase)

      @projekt_phase.budget&.heading.blank?
    end
end
