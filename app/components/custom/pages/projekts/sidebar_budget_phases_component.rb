class Pages::Projekts::SidebarBudgetPhasesComponent < ApplicationComponent
  delegate :format_date_range, :format_date, to: :helpers
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

  def phase_duration_text(phase)
    today = Time.zone.today

    if budget_phase_expired?(phase)
      I18n.t("custom.projekts.page.sidebar.phases.ended_on", date: format_date(phase.ends_at))
    elsif phase.current?
      if phase.ends_at.present?
        I18n.t("custom.projekts.page.sidebar.phases.running_until", date: format_date(phase.ends_at))
      else
        I18n.t("custom.projekts.page.sidebar.phases.running")
      end
    elsif phase.starts_at.present?
      days = (phase.starts_at.to_date - today).to_i
      I18n.t("custom.projekts.page.sidebar.phases.starts_in", count: days)
    else
      format_date_range(phase.starts_at, phase.ends_at&.to_date)
    end
  end
end
