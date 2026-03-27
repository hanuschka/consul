class Adm::Officing::DashboardController < Adm::Officing::BaseController
  skip_after_action :verify_policy_scoped, only: :index

  def index
    authorize :base, policy_class: Adm::Officing::BasePolicy

    @budgets = (
      (@officing_manager&.balloting_budgets || []) +
      (@officing_manager&.selecting_budgets || [])
    ).uniq
  end
end
