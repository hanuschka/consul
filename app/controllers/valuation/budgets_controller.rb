class Valuation::BudgetsController < Valuation::BaseController
  include FeatureFlags
  feature_flag :budgets

  def index
    @budgets = Budget.joins(:valuators)
      .where(valuators: { id: current_user&.valuator&.id })
      .select { |budget| budget.current_phase.kind.in?(%w[accepting reviewing selecting valuating]) }
      .uniq
  end
end
