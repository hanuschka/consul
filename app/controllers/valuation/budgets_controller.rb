class Valuation::BudgetsController < Valuation::BaseController
  include FeatureFlags
  feature_flag :budgets

  def index
    @budgets = Budget.joins(:valuators)
                     .where(valuators: { id: current_user.valuator.id })
                     .select(&:valuating?)
                     .uniq
  end
end
