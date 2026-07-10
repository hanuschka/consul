class Pages::Projekts::BudgetsSubnavComponent < ApplicationComponent
  delegate :current_user, :can?,
    :footer_evaluation_tab_visible?, :footer_evaluation_tab_public_visible?,
    :footer_evaluation_tab_disabled?, to: :helpers
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

      if can?(:read_stats, budget) && footer_evaluation_tab_visible?(projekt_phase, "stats")
        items << {
          text: t("custom.projekt_phases.subnav.evaluation"),
          url: url_to_footer_tab(section: "evaluation", remote: true),
          active: params[:section] == "evaluation",
          section: "evaluation",
          hide_on_preview: !footer_evaluation_tab_public_visible?(projekt_phase, "stats")
        }
      end

      if can?(:read_stats, budget) && footer_evaluation_tab_visible?(projekt_phase, "ai")
        items << {
          text: t("custom.projekt_phases.subnav.ai_evaluation"),
          url: url_to_footer_tab(section: "ai_evaluation", remote: true),
          active: params[:section] == "ai_evaluation",
          disabled: footer_evaluation_tab_disabled?(projekt_phase, "ai"),
          section: "ai_evaluation",
          hide_on_preview: !footer_evaluation_tab_public_visible?(projekt_phase, "ai")
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
end
