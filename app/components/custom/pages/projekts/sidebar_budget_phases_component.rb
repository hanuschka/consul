class Pages::Projekts::SidebarBudgetPhasesComponent < ApplicationComponent
  delegate :format_budget_phase_duration, to: :helpers
  attr_reader :budget, :phases

  def initialize(budget)
    @budget = budget
    @phases = budget.published_phases.includes(:translations)
  end

  private
end
