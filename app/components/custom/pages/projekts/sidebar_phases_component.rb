class Pages::Projekts::SidebarPhasesComponent < ApplicationComponent
  delegate :format_date_range, :format_date, :projekt_feature?, :projekt_phase_feature?, to: :helpers
  attr_reader :projekt, :phases, :milestone_phase

  def initialize(projekt)
    @projekt = projekt
    @phases = projekt.projekt_phases.includes(:translations).active.sorted
    @milestone_phase = projekt.milestone_phases.first
  end

  def render?
    @projekt.show_start_date_in_frontend? || @projekt.show_end_date_in_frontend? || phases.any?
  end

  def phase_status_class(phase)
    return "-completed" if phase.expired?
    return "-current" if phase.current?

    "-upcoming"
  end

  def phase_status_for_date(date)
    return nil if date.blank?

    today = Time.zone.today
    if date < today
      "-completed"
    elsif date == today
      "-current"
    else
      "-upcoming"
    end
  end

  def phase_duration_text(phase)
    today = Time.zone.today

    if phase.expired? && phase.end_date.present?
      I18n.t("custom.projekts.page.sidebar.phases.ended_on", date: format_date(phase.end_date))
    elsif phase.current?
      if phase.end_date.present?
        I18n.t("custom.projekts.page.sidebar.phases.running_until", date: format_date(phase.end_date))
      else
        I18n.t("custom.projekts.page.sidebar.phases.running")
      end
    else
      if phase.start_date.present?
        days = (phase.start_date - today).to_i
        I18n.t("custom.projekts.page.sidebar.phases.starts_in", count: days)
      else
        format_date_range(phase.start_date, phase.end_date)
      end
    end
  end

  private

    def show_cta?
      return true if projekt.budget_phases.any?(&:current?) && projekt.budgets.any?{ |budget| budget.current_phase.kind.in?(%w[accepting selecting balloting]) }

      phases.any? { |phase| phase.type != "ProjektPhase::BudgetPhase" && phase.current? }
    end
end
