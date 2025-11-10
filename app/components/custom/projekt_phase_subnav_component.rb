class ProjektPhaseSubnavComponent < ApplicationComponent
  delegate :current_user, :can?, to: :helpers

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def render?
    can?(:read_stats, @projekt_phase)
  end

  def projekt_phase_subnav_items
    [
      {
        text: t("custom.projekt_phases.subnav.stats"),
        url:  url_to_footer_tab(section: "stats", remote: true),
        active: params[:section] == "stats"
      },
      {
        text: t("custom.projekt_phases.subnav.overview.#{@projekt_phase.name}"),
        url: url_to_footer_tab(section: "overview", remote: true),
        active: params[:section].blank? || params[:section] == "overview"
      }
    ]
  end
end
