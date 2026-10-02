class Api::ProjektPhasesController < Api::BaseController
  include Translatable

  before_action :find_projekt, only: %i[index new create]
  before_action :find_projekt_phase, only: [:show, :update, :destroy, :update_setting, :update_settings]

  def index
    check_read_access!
    projekt_phases = @projekt.projekt_phases
      .includes(
        :settings,
        :individual_group_values,
        :geozone_restrictions
      )

    if current_client.public_data?
      projekt_phases = projekt_phases.frontend_visible.active
    end

    projekt_phases = paginate(projekt_phases.order(:id))

    serialized_projekt_phases = ProjektPhaseSerializer.serialize_collection(
      projekt_phases,
      current_api_client: current_client
    )

    render json: {
      data: { projekt_phases: serialized_projekt_phases },
      pagination: pagination_meta(projekt_phases)
    }
  end

  def show
    check_read_access!

    if current_client.public_data?
      unless @projekt_phase.frontend_visibility && @projekt_phase.active?
        return render json: { error: { type: 'forbidden', messages: ['Access denied'] } }, status: 403
      end
    end

    serialized_projekt_phase = ProjektPhaseSerializer.new(
      @projekt_phase,
      current_api_client: current_client
    ).serialize

    render json: { data: { projekt_phase: serialized_projekt_phase } }
  end

  def create
    check_admin_access!
    phase_class = resolve_phase_class(params.dig(:projekt_phase, :type))
    projekt_phase = phase_class.new(projekt_phase_params.except(:type))
    projekt_phase.projekt = @projekt

    if projekt_phase.save
      serialized_projekt_phase = ProjektPhaseSerializer.new(projekt_phase).serialize

      render json: { data: { projekt_phase: serialized_projekt_phase } }, status: 201
    else
      render json: { error: { messages: projekt_phase.errors.full_messages } }, status: 422
    end
  end

  def update
    check_admin_access!
    if @projekt_phase.update(projekt_phase_params)
      serialized_projekt_phase = ProjektPhaseSerializer.new(@projekt_phase).serialize

      render json: { data: { projekt_phase: serialized_projekt_phase } }
    else
      render json: { error: { messages: @projekt_phase.errors.full_messages } }, status: 422
    end
  end

  def destroy
    check_admin_access!
    if @projekt_phase.destroy
      render json: { message: "Projekt phase destroyed" }
    else
      render json: { error: { messages: @projekt_phase.errors.messages } }, status: 422
    end
  end

  def update_setting
    check_admin_access!
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

  def update_settings
    check_admin_access!
    settings_hash = params[:settings]

    if settings_hash.blank?
      return render json: { error: { messages: ["settings parameter is required"] } }, status: 422
    end

    updated = []
    errors = {}

    settings_hash.each do |key, value|
      setting = @projekt_phase.settings.find_or_initialize_by(key: key)

      if setting.update(value: value.to_s)
        updated << key
      else
        errors[key] = setting.errors.full_messages
      end
    end

    render json: { data: { updated: updated, errors: errors } }
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
      :registered_address_grouping_restriction,
      *translation_params(ProjektPhase),
      registered_address_grouping_restrictions: {},
      individual_group_value_ids: [],
      geozone_restriction_ids: [],
      settings_attributes: [:id, :key, :value, :_destroy],
    )
  end

  def resolve_phase_class(type_name)
    return ProjektPhase if type_name.blank?

    phase_class_map[type_name] || ProjektPhase
  end

  def phase_class_map
    ProjektPhase::ALL_PHASE_TYPES.each_with_object({}) do |name, map|
      map[name] = name.safe_constantize
    end
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

