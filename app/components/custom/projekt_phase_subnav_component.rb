class ProjektPhaseSubnavComponent < ApplicationComponent
  delegate :current_user, :can?, :phase_icon_class,
    :footer_evaluation_tab_public_visible?, :footer_evaluation_tab_available?,
    :footer_evaluation_tab_disabled?, :hidden_from_public_tooltip,
    :footer_evaluation_tab_label, to: :helpers

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

    if voting_phase? && show_evaluation_tab?("poll_stats")
      items << {
        text: footer_evaluation_tab_label(@projekt_phase, "poll_stats"),
        icon: "fa-chart-pie",
        url: url_to_footer_tab(section: "poll_stats", remote: true),
        active: params[:section] == "poll_stats",
        section: "poll_stats",
        visibility_group: "poll_stats",
        hidden_from_public: evaluation_tab_hidden_from_public?("poll_stats")
      }
    end

    if show_evaluation_tab?("stats")
      items << {
        text: stats_tab_text,
        icon: "fa-chart-bar",
        url: url_to_footer_tab(section: "evaluation", remote: true),
        active: params[:section] == "evaluation",
        section: "evaluation",
        visibility_group: "stats",
        hidden_from_public: evaluation_tab_hidden_from_public?("stats")
      }
    end

    if show_evaluation_tab?("ai")
      items << {
        text: ai_tab_text,
        icon: "fa-magic",
        url: url_to_footer_tab(section: "ai_evaluation", remote: true),
        active: params[:section] == "ai_evaluation",
        disabled: footer_evaluation_tab_disabled?(@projekt_phase, "ai"),
        section: "ai_evaluation",
        visibility_group: "ai",
        hidden_from_public: evaluation_tab_hidden_from_public?("ai")
      }
    end

    items
  end

  private

    def voting_phase?
      @projekt_phase.is_a?(ProjektPhase::VotingPhase)
    end

    def stats_tab_text
      footer_evaluation_tab_label(@projekt_phase, "stats")
    end

    def ai_tab_text
      footer_evaluation_tab_label(@projekt_phase, "ai")
    end

    def show_evaluation_tab?(tab)
      footer_evaluation_tab_available?(@projekt_phase, tab)
    end

    def evaluation_tab_hidden_from_public?(tab)
      !footer_evaluation_tab_public_visible?(@projekt_phase, tab)
    end

    def tab_tooltip_hidden_state(item)
      return nil if item[:visibility_group].blank?
      return nil if !can?(:edit, @projekt_phase.projekt)

      item[:hidden_from_public]
    end

    def any_tab_public_visible?
      footer_evaluation_tab_public_visible?(@projekt_phase, "stats") ||
        footer_evaluation_tab_public_visible?(@projekt_phase, "ai") ||
        (voting_phase? && footer_evaluation_tab_public_visible?(@projekt_phase, "poll_stats"))
    end

    def hide_subnav_on_preview?
      !any_tab_public_visible?
    end
end
