class Api::ProjektPhasesController < Api::BaseController
  include Translatable

  before_action :find_projekt
  before_action :find_projekt_phase, only: [:show, :update, :destroy]

  def index
    projekt_phases = @projekt.projekt_phases

    serialized_projekt_phases = ProjektPhaseSerializer.serialize_collection(projekt_phases)

    render json: { data: { projekt_phases: serialized_projekt_phases } }
  end

  def show
    serialized_projekt_phase = ProjektPhaseSerializer.new(@projekt_phase).serialize

    render json: { data: { projekt_phase: serialized_projekt_phase } }
  end

  def create
    projekt_phase = @projekt.projekt_phases.new(projekt_phase_params)

    if projekt_phase.save
      serialized_projekt_phase = ProjektPhaseSerializer.new(projekt_phase).serialize

      render json: { data: { projekt_phase: serialized_projekt_phase } }, status: 201
    else
      render json: { error: { messages: projekt_phase.errors.full_messages } }, status: 422
    end
  end

  def update
    if @projekt_phase.update(projekt_phase_params)
      serialized_projekt_phase = ProjektPhaseSerializer.new(@projekt_phase).serialize

      render json: { data: { projekt_phase: serialized_projekt_phase } }
    else
      render json: { error: { messages: @projekt_phase.errors.full_messages } }, status: 422
    end
  end

  def destroy
    if @projekt_phase.destroy
      render json: { message: "Projekt phase destroyed" }
    else
      render json: { error: { messages: @projekt_phase.errors.messages } }, status: 422
    end
  end

  private

  def projekt_phase_params
    processed_params = params.require(:projekt_phase).permit(
      :type,
      :start_date,
      :end_date,
      :active,
      :frontend_visibility,
      :given_order,
      :geozone_restricted,
      :age_range_id,
      :user_status,
      :lock_on,
      :registered_address_grouping_restriction,
      registered_address_grouping_restrictions: {},
      individual_group_value_ids: [],
      geozone_restriction_ids: [],
      settings_attributes: [:id, :key, :value, :_destroy],
      translation_params(ProjektPhase)
    )

    processed_params
  end

  def find_projekt
    @projekt = Projekt.find(params[:projekt_id])
  end

  def find_projekt_phase
    @projekt_phase = @projekt.projekt_phases.find(params[:id])
  end
end

