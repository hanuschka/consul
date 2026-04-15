class Pages::Projekts::BudgetsSubnavComponent < ApplicationComponent
  delegate :current_user, :can?, to: :helpers
  attr_reader :budget, :projekt_phase

  def initialize(budget, projekt_phase)
    @budget = budget
    @projekt_phase = projekt_phase
  end

  private

    def budget_subnav_items_for(budget)
      items = []

      items << overview_item

      if can?(:read_results, budget)
        items << {
          text: t("budgets.results.link"),
          url: url_to_footer_tab(section: "results", remote: true),
          active: params[:section] == "results",
          section: "results",
          hide_on_preview: !budget.results_enabled?
        }
      end

      if can?(:read_stats, budget) && show_kpi_stats_tab?
        items << {
          text: t("custom.projekt_phases.subnav.key_metrics"),
          url: url_to_footer_tab(section: "key_metrics", remote: true),
          active: params[:section] == "key_metrics",
          section: "key_metrics",
          hide_on_preview: !projekt_phase.feature?("general.public_kpi_stats")
        }
      end

      if can?(:read_stats, budget) && show_ai_analysis_tab?
        items << {
          text: t("custom.projekt_phases.subnav.analysis"),
          url: url_to_footer_tab(section: "analysis", remote: true),
          active: params[:section] == "analysis",
          disabled: !Ai::Settings.ai_available?,
          section: "analysis",
          hide_on_preview: !projekt_phase.feature?("general.public_ai_stats")
        }
      end

      items
    end

    def overview_item
      {
        text: t("custom.projekts.page.footer.budget.investments_subtab"),
        url: url_to_footer_tab(section: "", remote: true),
        active: params[:section].blank? || params[:section] == "overview",
        section: "overview"
      }
    end

    def admin_or_projekt_manager?
      current_user&.administrator? || current_user&.projekt_manager?
    end

    def show_kpi_stats_tab?
      admin_or_projekt_manager? || projekt_phase.feature?("general.public_kpi_stats")
    end

    def show_ai_analysis_tab?
      admin_or_projekt_manager? || projekt_phase.feature?("general.public_ai_stats")
    end
end
