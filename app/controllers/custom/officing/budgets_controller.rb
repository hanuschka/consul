class Officing::BudgetsController < Officing::BaseController
  include OfficingActions

  def officing_desk
    @budget = Budget.find(params[:id])
    @heading = @budget.heading

    if @budget.in?(@officing_manager.balloting_budgets)
      @ballot = Budget::Ballot.where(user: @offline_user, budget: @budget)
                              .first_or_create!(conditional: false, physical: true)
      @investments = @budget.investments.selected
      @investment_ids = @investments.ids
    elsif @budget.in? @officing_manager.selecting_budgets
      debugger
    else
      raise ActionController::RoutingError.new('Not Found')
    end
  end
end
