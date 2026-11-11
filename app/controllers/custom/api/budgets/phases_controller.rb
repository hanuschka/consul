class Api::Budgets::PhasesController < Api::BaseController
  before_action :find_budget, only: [:index, :bulk_update]
  before_action :find_phase, only: [:show, :update]

  def index
    check_read_access!
    phases = paginate(@budget.phases.order(:id))

    render json: {
      data: {
        budget_phases: phases.map { |phase| serialize_phase(phase) }
      },
      pagination: pagination_meta(phases)
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

  def bulk_update
    check_admin_access!
    phase_entries = bulk_phase_params

    if phase_entries.nil?
      return render_bad_request("budget_phases must be an array of phase objects.")
    end

    result = BudgetPhases::BulkUpdateService.call(@budget, phase_entries)

    if result.success?
      render json: {
        data: {
          budget_phases: result.data[:phases].map { |phase| serialize_phase(phase) }
        }
      }
    else
      render json: { error: { messages: result.error } }, status: 422
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

  def bulk_phase_params
    return if !params.require(:budget_phases).is_a?(Array)

    params
      .permit(budget_phases: [:kind, *BudgetPhases::BulkUpdateService::EDITABLE_ATTRIBUTES])
      .fetch(:budget_phases)
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
