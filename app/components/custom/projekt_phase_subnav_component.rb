class ProjektPhaseSubnavComponent < ApplicationComponent
  delegate :current_user, :can?, to: :helpers

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def render?
    can?(:read_stats, @projekt_phase) && (admin_or_projekt_manager? || any_public_stats_enabled?)
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

    if show_kpi_stats_tab?
      items << {
        text: t("custom.projekt_phases.subnav.key_metrics"),
        url:  url_to_footer_tab(section: "key_metrics", remote: true),
        active: params[:section] == "key_metrics",
        section: "key_metrics",
        hide_on_preview: !@projekt_phase.feature?("general.public_kpi_stats")
      }
    end

    if show_ai_analysis_tab?
      items << {
        text: t("custom.projekt_phases.subnav.analysis"),
        url:  url_to_footer_tab(section: "analysis", remote: true),
        active: params[:section] == "analysis",
        disabled: !Ai::Settings.ai_available?,
        section: "analysis",
        hide_on_preview: !@projekt_phase.feature?("general.public_ai_stats")
      }
    end

    items
  end

  private

    def admin_or_projekt_manager?
      current_user&.administrator? || current_user&.projekt_manager?
    end

    def show_kpi_stats_tab?
      return false if @projekt_phase.is_a?(ProjektPhase::CommentPhase)

      admin_or_projekt_manager? || @projekt_phase.feature?("general.public_kpi_stats")
    end

    def show_ai_analysis_tab?
      admin_or_projekt_manager? || @projekt_phase.feature?("general.public_ai_stats")
    end

    def any_public_stats_enabled?
      @projekt_phase.feature?("general.public_kpi_stats") ||
        @projekt_phase.feature?("general.public_ai_stats")
    end

    def hide_subnav_on_preview?
      !any_public_stats_enabled?
    end
end
