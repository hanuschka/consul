class Adm::Officing::BudgetInvestmentVotesController < Adm::Officing::BaseController
  include Adm::Officing::BudgetScoped

  before_action :load_budget
  before_action :verify_assignment
  before_action :load_offline_user
  before_action :load_investment

  def create
    authorize :base, policy_class: Adm::Officing::BasePolicy

    @investment.vote_by(voter: @offline_user, vote: "yes", vote_weight: params[:vote_weight].presence || 1)

    redirect_to officing_desk_adm_officing_budget_path(@budget, offline_user_id: @offline_user.id)
  end

  def destroy
    authorize :base, policy_class: Adm::Officing::BasePolicy

    @investment.unliked_by(@offline_user)

    redirect_to officing_desk_adm_officing_budget_path(@budget, offline_user_id: @offline_user.id)
  end

  private

    def verify_assignment
      unless @budget.in?(@officing_manager.selecting_budgets)
        raise ActionController::RoutingError, "Not Found"
      end
    end

    def load_investment
      @investment = @budget.investments.find(params[:investment_id] || params[:id])
    end
end
