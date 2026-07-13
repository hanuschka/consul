class ProjektPhaseSubnavComponent < ApplicationComponent
  delegate :current_user, :can?, :phase_icon_class,
    :footer_evaluation_tab_public_visible?, :footer_evaluation_tab_has_content?,
    :footer_evaluation_tab_disabled?, to: :helpers

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def render?
    return false if !can?(:read_stats, @projekt_phase)

    projekt_phase_subnav_items.size > 1
  end

  def projekt_phase_subnav_items
    items = [
      {
        text: @projekt_phase.title.presence || t("custom.projekt_phases.subnav.overview.#{@projekt_phase.name}"),
        icon: phase_icon_class(@projekt_phase) || "fa-list",
        url: url_to_footer_tab(section: "", remote: true),
        active: params[:section].blank? || params[:section] == "overview",
        section: "overview"
      }
    ]

    if show_evaluation_tab?("stats")
      items << {
        text: t("custom.projekt_phases.subnav.evaluation"),
        icon: "fa-chart-bar",
        url: url_to_footer_tab(section: "evaluation", remote: true),
        active: params[:section] == "evaluation",
        section: "evaluation",
        hidden_from_public: evaluation_tab_hidden_from_public?("stats")
      }
    end

    if show_evaluation_tab?("ai")
      items << {
        text: t("custom.projekt_phases.subnav.ai_evaluation"),
        icon: "fa-magic",
        url: url_to_footer_tab(section: "ai_evaluation", remote: true),
        active: params[:section] == "ai_evaluation",
        disabled: footer_evaluation_tab_disabled?(@projekt_phase, "ai"),
        section: "ai_evaluation",
        hidden_from_public: evaluation_tab_hidden_from_public?("ai")
      }
    end

    items
  end

  private

    def can_manage_projekt?
      can?(:edit, @projekt_phase.projekt)
    end

    def show_evaluation_tab?(tab)
      return false if !footer_evaluation_tab_has_content?(@projekt_phase, tab)

      footer_evaluation_tab_public_visible?(@projekt_phase, tab) || can_manage_projekt?
    end

    def evaluation_tab_hidden_from_public?(tab)
      !footer_evaluation_tab_public_visible?(@projekt_phase, tab)
    end

    def any_tab_public_visible?
      footer_evaluation_tab_public_visible?(@projekt_phase, "stats") ||
        footer_evaluation_tab_public_visible?(@projekt_phase, "ai")
    end

    def hide_subnav_on_preview?
      !any_tab_public_visible?
    end
end
