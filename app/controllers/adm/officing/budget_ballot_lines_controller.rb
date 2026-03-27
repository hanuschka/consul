class Adm::Officing::BudgetBallotLinesController < Adm::Officing::BaseController
  before_action :load_budget
  before_action :verify_assignment
  before_action :load_offline_user
  before_action :load_ballot

  def create
    authorize :base, policy_class: Adm::Officing::BasePolicy

    investment = Budget::Investment.find(params[:investment_id])
    @ballot.add_investment(investment, params[:line_weight])

    redirect_to officing_desk_adm_officing_budget_path(@budget, offline_user_id: @offline_user.id)
  end

  def destroy
    authorize :base, policy_class: Adm::Officing::BasePolicy

    line = @ballot.lines.find(params[:id])
    line.destroy!

    redirect_to officing_desk_adm_officing_budget_path(@budget, offline_user_id: @offline_user.id)
  end

  private

    def verify_assignment
      unless @budget.in?(@officing_manager.balloting_budgets)
        raise ActionController::RoutingError, "Not Found"
      end
    end

    def load_ballot
      @ballot = Budget::Ballot.find_by!(user: @offline_user, budget: @budget)
    end

    def officing_desk_path(offline_user)
      officing_desk_adm_officing_budget_path(@budget, offline_user_id: offline_user.id)
    end
end
