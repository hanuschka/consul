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
        text: t("custom.projekt_phases.subnav.overview.#{@projekt_phase.name}"),
        url: url_to_footer_tab(section: nil, remote: true),
        active: params[:section].blank? || params[:section] == "overview"
      },
      {
        text: t("custom.projekt_phases.subnav.key_metrics"),
        url:  url_to_footer_tab(section: "key_metrics", remote: true),
        active: params[:section] == "key_metrics"
      },
      {
        text: t("custom.projekt_phases.subnav.analysis"),
        url:  url_to_footer_tab(section: "analysis", remote: true),
        active: params[:section] == "analysis"
      }
    ]
  end
end
