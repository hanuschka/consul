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

    phases_params = params.require(:budget_phases)
    updated_phases = []
    errors = []

    phases_params.each do |phase_params|
      phase = @budget.phases.find_by(kind: phase_params[:kind])

      if phase.blank?
        errors << "Phase with kind '#{phase_params[:kind]}' not found"
        next
      end

      columns = {}
      columns[:starts_at] = phase_params[:starts_at] if phase_params.key?(:starts_at)
      columns[:ends_at] = phase_params[:ends_at] if phase_params.key?(:ends_at)
      columns[:enabled] = phase_params[:enabled] if phase_params.key?(:enabled)

      if columns.present?
        phase.update_columns(columns)
        phase.reload
      end

      updated_phases << phase
    end

    if errors.present?
      render json: { error: { messages: errors } }, status: 422
    else
      render json: {
        data: {
          budget_phases: updated_phases.map { |p| serialize_phase(p) }
        }
      }
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
