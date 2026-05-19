class Adm::Valuation::InvestmentsController < Adm::Valuation::BaseController
  before_action :load_investment, only: [:edit, :update]

  def edit
    authorize @investment, policy_class: Adm::Valuation::BudgetInvestmentPolicy
  end

  def update
    authorize @investment, policy_class: Adm::Valuation::BudgetInvestmentPolicy

    if @investment.update(valuation_params)
      send_feasibility_emails if feasibility_email_needed?

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

    def feasibility_email_needed?
      valuation_params[:feasibility].present? &&
        @investment.valuation_finished? &&
        @investment.email_on_feasibility_pending?
    end

    def send_feasibility_emails
      if @investment.unfeasible?
        Mailer.budget_investment_unfeasible(@investment).deliver_later
      elsif @investment.feasible?
        Mailer.budget_investment_feasible(@investment).deliver_later
      end
      @investment.update_column(:email_on_feasibility_sent_at, Time.zone.now)
    end
end
