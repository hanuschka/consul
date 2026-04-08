class Api::Budgets::PhasesController < Api::BaseController
  before_action :find_budget, only: [:index]
  before_action :find_phase, only: [:show, :update]

  def index
    check_read_access!
    phases = @budget.phases.order(:id)

    render json: {
      data: {
        budget_phases: phases.map { |p| serialize_phase(p) }
      }
    }
  end

  def show
    check_read_access!

    render json: { data: { budget_phase: serialize_phase(@phase) } }
  end

  def update
    check_admin_access!

    if @phase.update(phase_params)
      render json: { data: { budget_phase: serialize_phase(@phase) } }
    else
      render json: { error: { messages: @phase.errors.full_messages } }, status: 422
    end
  end

  private

  def phase_params
    params.require(:budget_phase).permit(
      :starts_at,
      :ends_at,
      :enabled
    )
  end

  def find_budget
    @budget = Budget.find(params[:budget_id])
  end

  def find_phase
    @phase = Budget::Phase.find(params[:id])
  end

  def serialize_phase(phase)
    {
      id: phase.id,
      kind: phase.kind,
      name: phase.name,
      starts_at: phase.starts_at,
      ends_at: phase.ends_at,
      enabled: phase.enabled
    }
  end
end
