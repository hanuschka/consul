class Adm::Projekts::Milestones::BudgetInvestmentsController < Adm::Projekts::Milestones::BaseController
  private

    def set_milestoneable
      @investment = @projekt_phase.budget.investments.find(params[:budget_investment_id])
      @milestoneable = @investment
    end

    def milestones_index_url
      milestones_adm_projekts_phase_budget_investment_path(@projekt_phase, @investment)
    end

    def new_milestone_url
      new_adm_projekts_phase_budget_investment_milestone_path(@projekt_phase, @investment)
    end

    def edit_milestone_url(milestone)
      edit_adm_projekts_phase_budget_investment_milestone_path(@projekt_phase, @investment, milestone)
    end

    def delete_milestone_url(milestone)
      adm_projekts_phase_budget_investment_milestone_path(@projekt_phase, @investment, milestone)
    end

    def milestone_update_url(milestone)
      adm_projekts_phase_budget_investment_milestone_path(@projekt_phase, @investment, milestone)
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.budget_investments.title"), url: budget_investments_adm_projekts_phase_path(@projekt_phase) },
        { name: @investment.title, url: adm_projekts_phase_budget_investment_path(@projekt_phase, @investment) },
        { name: t("adm.projekts.budget_investments.milestones.title"), url: milestones_index_url },
        { name: action_title }
      ]
    end
end
