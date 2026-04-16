module Adm::Officing::BudgetScoped
  extend ActiveSupport::Concern

  private

    def load_budget
      @budget = Budget.find(params[:budget_id] || params[:id])
    end

    def officing_desk_path(offline_user)
      officing_desk_adm_officing_budget_path(@budget, offline_user_id: offline_user.id)
    end

    def assigned_budgets
      (@officing_manager.balloting_budgets + @officing_manager.selecting_budgets).uniq
    end
end
