class ProjektPhaseSubnavComponent < ApplicationComponent
  delegate :current_user, :can?, to: :helpers

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def render?
    can?(:read_stats, @projekt_phase)
  end

  def projekt_phase_subnav_items
    items = [
      {
        text: t("custom.projekt_phases.subnav.overview.#{@projekt_phase.name}"),
        url: url_to_footer_tab(section: "", remote: true),
        active: params[:section].blank? || params[:section] == "overview",
        section: "overview"
      }
    ]

    unless @projekt_phase.is_a?(ProjektPhase::CommentPhase)
      items << {
        text: t("custom.projekt_phases.subnav.key_metrics"),
        url:  url_to_footer_tab(section: "key_metrics", remote: true),
        active: params[:section] == "key_metrics",
        section: "key_metrics"
      }
    end

    items << {
      text: t("custom.projekt_phases.subnav.analysis"),
      url:  url_to_footer_tab(section: "analysis", remote: true),
      active: params[:section] == "analysis",
      disabled: !Ai::Settings.ai_available?,
      section: "analysis"
    }

    items
  end
end
