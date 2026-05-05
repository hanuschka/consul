class Adm::Officing::BudgetsController < Adm::Officing::BaseController
  include Adm::Officing::BudgetScoped

  before_action :load_budget
  before_action :verify_assignment

  def officing_desk
    authorize :base, policy_class: Adm::Officing::BasePolicy

    @offline_user = User.find(params[:offline_user_id])

    @permission_problem = @budget.projekt_phase.permission_problem(@offline_user, location: :officing)

    if @permission_problem.present?
      render "adm/officing/shared/permission_problem" and return
    end

    if @budget.balloting? || @budget.reviewing_ballots?
      @ballot = Budget::Ballot.where(user: @offline_user, budget: @budget)
                              .first_or_create!(conditional: false, physical: true)
      investments = @budget.investments.selected
      @lines_by_investment_id = @ballot.lines.index_by(&:investment_id)
    elsif @budget.selecting? || @budget.valuating?
      investments = @budget.investments.feasible
    end

    if investments
      @pagy, @investments = pagy(investments, items: 50)
    end
  end

  private

    def verify_assignment
      unless @budget.in?(assigned_budgets)
        raise ActionController::RoutingError, "Not Found"
      end
    end
end
