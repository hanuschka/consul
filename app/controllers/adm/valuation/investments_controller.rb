class Adm::Valuation::InvestmentsController < Adm::Valuation::BaseController
  before_action :load_investment, only: [:edit, :update]

  def edit
    authorize @investment, policy_class: Adm::Valuation::BudgetInvestmentPolicy
  end

  def update
    authorize @investment, policy_class: Adm::Valuation::BudgetInvestmentPolicy

    if @investment.update(valuation_params)
      @investment.send_feasibility_email if valuation_params[:feasibility].present?

      Activity.log(current_user, :valuate, @investment)
      redirect_to edit_adm_valuation_investment_path(@investment),
                  notice: t("adm.valuation.investments.notice.updated")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

    def load_investment
      @investment = Budget::Investment.find(params[:id])
    end

    def valuation_params
      params.require(:budget_investment).permit(
        :feasibility, :valuator_explanation, :valuation_finished
      )
    end
end
