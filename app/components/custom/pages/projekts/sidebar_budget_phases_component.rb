class Pages::Projekts::SidebarBudgetPhasesComponent < ApplicationComponent
  delegate :format_budget_phase_duration, to: :helpers
  attr_reader :budget, :phases

  def initialize(budget)
    @budget = budget
    @phases = budget.published_phases.includes(:translations)
  end

  def phase_status_class(phase)
    return "-completed" if budget_phase_expired?(phase)
    return "-current" if phase.current?

    "-upcoming"
  end

  def budget_phase_expired?(phase)
    phase.ends_at.present? && phase.ends_at < Time.zone.now
  end
end
