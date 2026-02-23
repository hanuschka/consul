class Adm::Projekts::BudgetsController < Adm::Projekts::BaseController
  before_action :set_projekt_phase
  before_action :set_budget

  def calculate_winners
    authorize [:adm, :projekts, @budget]

    Budget::Result.new(@budget, @budget.heading).delay.calculate_winners
    redirect_to budget_investments_adm_projekts_phase_path(@projekt_phase),
      notice: t(".notice")
  end

  def recalculate_winners
    authorize [:adm, :projekts, @budget]

    Budget::Result.new(@budget, @budget.heading).calculate_winners
    redirect_to budget_investments_adm_projekts_phase_path(@projekt_phase),
      notice: t(".notice")
  end

  def update
    authorize [:adm, :projekts, @budget]

    if @budget.update(budget_params)
      flash.now[:success] = t("adm.attribute.update.success")
    end

    render turbo_stream: turbo_stream.replace(
      turbo_frame_request_id,
      partial: partial_for_frame,
      locals: { budget: @budget, projekt_phase: @projekt_phase }
    )
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def set_budget
      @budget = @projekt_phase.budget
    end

    def budget_params
      params.require(:budget).permit(administrator_ids: [], valuator_ids: [])
    end

    def partial_for_frame
      frame_id = turbo_frame_request_id
      case frame_id
      when "budget_administrators"
        "adm/projekts/phases/budget_edit/administrators"
      when "budget_valuators"
        "adm/projekts/phases/budget_edit/valuators"
      end
    end
end
