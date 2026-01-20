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
          active: params[:section] == "results"
        }
      end

      if can?(:read_stats, budget)
        items << {
          text: t("custom.projekt_phases.subnav.key_metrics"),
          url: url_to_footer_tab(section: "key_metrics", remote: true),
          active: params[:section] == "key_metrics"
        }

        if Ai::Settings.ai_available?
          items << {
            text: t("custom.projekt_phases.subnav.analysis"),
            url: url_to_footer_tab(section: "analysis", remote: true),
            active: params[:section] == "analysis"
          }
        end
      end

      items
    end

    def overview_item
      {
        text: t("custom.projekts.page.footer.budget.investments_subtab"),
        url: url_to_footer_tab(section: "", remote: true),
        active: params[:section].blank? || params[:section] == "overview"
      }
    end
end
