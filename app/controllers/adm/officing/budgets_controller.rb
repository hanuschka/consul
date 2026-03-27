class Adm::Officing::BudgetsController < Adm::Officing::BaseController
  before_action :load_budget
  before_action :verify_assignment

  def officing_desk
    authorize :base, policy_class: Adm::Officing::BasePolicy

    @offline_user = User.find(params[:offline_user_id])

    @permission_problem = @budget.projekt_phase.permission_problem(@offline_user)

    if @permission_problem.present?
      render "adm/officing/shared/permission_problem" and return
    end

    if @budget.balloting? || @budget.reviewing_ballots?
      @ballot = Budget::Ballot.where(user: @offline_user, budget: @budget)
                              .first_or_create!(conditional: false, physical: true)
      @investments = @budget.investments.selected
      @lines_by_investment_id = @ballot.lines.index_by(&:investment_id)
    elsif @budget.selecting? || @budget.valuating?
      @investments = @budget.investments.feasible
    end
  end

  private

    def load_budget
      @budget = Budget.find(params[:id])
    end

    def verify_assignment
      unless @budget.in?(assigned_budgets)
        raise ActionController::RoutingError, "Not Found"
      end
    end

    def assigned_budgets
      (@officing_manager.balloting_budgets + @officing_manager.selecting_budgets).uniq
    end

    def officing_desk_path(offline_user)
      officing_desk_adm_officing_budget_path(@budget, offline_user_id: offline_user.id)
    end
end
