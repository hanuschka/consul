class Adm::Projekts::ProgressBars::BudgetInvestmentsController < Adm::Projekts::ProgressBars::BaseController
  private

    def set_progressable
      @investment = @projekt_phase.budget.investments.find(params[:budget_investment_id])
      @progressable = @investment
    end

    def progress_bars_index_url
      progress_bars_adm_projekts_phase_budget_investment_path(@projekt_phase, @investment)
    end

    def progress_bar_update_url(progress_bar)
      adm_projekts_phase_budget_investment_progress_bar_path(@projekt_phase, @investment, progress_bar)
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
        { name: @projekt_phase.projekt.name, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.budget_investments.title"), url: budget_investments_adm_projekts_phase_path(@projekt_phase) },
        { name: @investment.title, url: adm_projekts_phase_budget_investment_path(@projekt_phase, @investment) },
        { name: t("adm.projekts.budget_investments.progress_bars.title"), url: progress_bars_index_url },
        { name: action_title }
      ]
    end
end
