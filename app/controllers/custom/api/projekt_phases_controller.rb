class Api::ProjektPhasesController < Api::BaseController
  include Translatable

  before_action :find_projekt, only: %i[index new create]
  before_action :find_projekt_phase, only: [:show, :update, :destroy, :update_setting]

  def index
    projekt_phases = @projekt.projekt_phases
      .includes(
        :settings,
        :individual_group_values,
        :geozone_restrictions
      )

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

  def update_setting
    name = params.dig(:projekt_phase_setting, :key)
    value = params.dig(:projekt_phase_setting, :value)

    unless name.present?
      return render json: { error: { messages: ["name is required"] } }, status: 422
    end

    setting = @projekt_phase.settings.find_or_initialize_by(key: name)
    if setting.update(value: value)
      render json: { data: { projekt_phase_setting: setting.as_json(only: [:id, :key, :value]).merge(key: setting.key) } }
    else
      render json: { error: { messages: setting.errors.full_messages } }, status: 422
    end
  end

  private

  def projekt_phase_params
    params.require(:projekt_phase).permit(
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
      *translation_params(ProjektPhase),
      :registered_address_grouping_restriction,
      registered_address_grouping_restrictions: {},
      individual_group_value_ids: [],
      geozone_restriction_ids: [],
      settings_attributes: [:id, :key, :value, :_destroy],
    )
  end

  def find_projekt
    @projekt = Projekt.find(params[:projekt_id])
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase
      .includes(
        :settings,
        :individual_group_values,
        :geozone_restrictions
      )
      .find(params[:id])
  end
end

