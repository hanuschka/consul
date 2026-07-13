class ProjektPhaseSubnavComponent < ApplicationComponent
  delegate :current_user, :can?, :phase_icon_class,
    :footer_evaluation_tab_visible?, :footer_evaluation_tab_public_visible?,
    :footer_evaluation_tab_disabled?, to: :helpers

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def render?
    return false if !can?(:read_stats, @projekt_phase)

    admin_or_projekt_manager? || any_tab_public_visible?
  end

  def projekt_phase_subnav_items
    items = [
      {
        text: t("custom.projekt_phases.subnav.overview.#{@projekt_phase.name}"),
        icon: phase_icon_class(@projekt_phase) || "fa-list",
        url: url_to_footer_tab(section: "", remote: true),
        active: params[:section].blank? || params[:section] == "overview",
        section: "overview"
      }
    ]

    if footer_evaluation_tab_visible?(@projekt_phase, "stats")
      items << {
        text: t("custom.projekt_phases.subnav.evaluation"),
        icon: "fa-chart-bar",
        url: url_to_footer_tab(section: "evaluation", remote: true),
        active: params[:section] == "evaluation",
        section: "evaluation",
        hide_on_preview: !footer_evaluation_tab_public_visible?(@projekt_phase, "stats")
      }
    end

    if footer_evaluation_tab_visible?(@projekt_phase, "ai")
      items << {
        text: t("custom.projekt_phases.subnav.ai_evaluation"),
        icon: "fa-magic",
        url: url_to_footer_tab(section: "ai_evaluation", remote: true),
        active: params[:section] == "ai_evaluation",
        disabled: footer_evaluation_tab_disabled?(@projekt_phase, "ai"),
        section: "ai_evaluation",
        hide_on_preview: !footer_evaluation_tab_public_visible?(@projekt_phase, "ai")
      }
    end

    items
  end

  private

    def admin_or_projekt_manager?
      current_user&.administrator? || current_user&.projekt_manager?
    end

    def any_tab_public_visible?
      footer_evaluation_tab_public_visible?(@projekt_phase, "stats") ||
        footer_evaluation_tab_public_visible?(@projekt_phase, "ai")
    end

    def hide_subnav_on_preview?
      !any_tab_public_visible?
    end
end
