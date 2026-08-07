class Whatsapp::ResourceCreationValidationService < ApplicationService
  def initialize(projekt_phase:, user:)
    @projekt_phase = projekt_phase
    @user = user
  end

  def call
    return :phase_missing if @projekt_phase.blank?
    return :not_logged_in if @user.blank?
    return :phase_not_supported if !supported_phase?
    return :creation_disabled if !@projekt_phase.selectable_by_users?
    return :ai_flow_disabled if !@projekt_phase.ai_flow_enabled?
    return :budget_heading_missing if budget_heading_missing?

    @projekt_phase.permission_problem(@user, location: :whatsapp_bot)
  end

  private

    # Same list the eligible-phases query offers from, so a phase the bot lists
    # and a phase the bot accepts cannot come apart.
    def supported_phase?
      Whatsapp::EligiblePhasesQuery::PHASE_CLASSES.include?(@projekt_phase.class)
    end

    # An investment cannot be built without the budget's heading, and a budget
    # here has exactly one (Budget has_one :heading, through: :group).
    def budget_heading_missing?
      return false if !@projekt_phase.is_a?(ProjektPhase::BudgetPhase)

      @projekt_phase.budget&.heading.blank?
    end
end
