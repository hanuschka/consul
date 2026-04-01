class Adm::Moderation::BudgetInvestmentsController < Adm::Moderation::BaseController
  FILTERS = %w[pending_flag_review with_ignored_flag hidden all].freeze

  def index
    authorize Budget::Investment, policy_class: Adm::Moderation::BudgetInvestmentPolicy
    base_scope = policy_scope(Budget::Investment, policy_scope_class: Adm::Moderation::BudgetInvestmentPolicy::Scope)
    @current_filter = FILTERS.include?(params[:filter]) ? params[:filter] : FILTERS.first
    base_scope = apply_filter(base_scope)
    @pagy, @budget_investments = pagy(BudgetInvestmentsQuery.call(base_scope, params))

    @title_header_options = { search: true }
    @flags_count_header_options = { sort: true }

    @breadcrumbs = [
      { name: I18n.t("adm.moderation.menu.title"), icon: "payments" },
      { name: I18n.t("adm.moderation.menu.budget_investments") }
    ]
  end

  def hide
    @budget_investment = Budget::Investment.find(params[:id])
    authorize @budget_investment, :hide?, policy_class: Adm::Moderation::BudgetInvestmentPolicy

    @budget_investment.hide
    Activity.log(current_user, :hide, @budget_investment)
    @budget_investment.reload
  end

  def unhide
    @budget_investment = Budget::Investment.with_hidden.find(params[:id])
    authorize @budget_investment, :unhide?, policy_class: Adm::Moderation::BudgetInvestmentPolicy

    @budget_investment.restore
    Activity.log(current_user, :restore, @budget_investment)
    @budget_investment.reload
  end

  def ignore_flag
    @budget_investment = Budget::Investment.find(params[:id])
    authorize @budget_investment, :ignore_flag?, policy_class: Adm::Moderation::BudgetInvestmentPolicy

    @budget_investment.ignore_flag
    @budget_investment.reload
  end

  private

    def apply_filter(scope)
      case @current_filter
      when "pending_flag_review"
        scope.pending_flag_review
      when "with_ignored_flag"
        scope.with_ignored_flag
      when "hidden"
        scope.only_hidden
      else
        scope
      end
    end
end
