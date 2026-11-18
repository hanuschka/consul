class Api::ProjektPhasesController < Api::BaseController
  include Translatable

  before_action :find_projekt, only: %i[index new create]
  before_action :find_projekt_phase, only: [:show, :update, :destroy, :update_setting, :update_settings]
  around_action :audit_changes_as_client, only: [:update_setting, :update_settings]

  def index
    check_read_access!
    projekt_phases = @projekt.projekt_phases
      .includes(
        :settings,
        :individual_group_values,
        :geozone_restrictions
      )

    if current_client.public_data?
      return render_access_denied unless @projekt.visible_for?(nil)

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

    return render_access_denied if current_client.public_data? && !public_phase?(@projekt_phase)

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
      serialized_projekt_phase = ProjektPhaseSerializer.new(projekt_phase, current_api_client: current_client).serialize

      render json: { data: { projekt_phase: serialized_projekt_phase } }, status: 201
    else
      render json: { error: { messages: projekt_phase.errors.full_messages } }, status: 422
    end
  end

  def update
    check_admin_access!
    if @projekt_phase.update(projekt_phase_params)
      serialized_projekt_phase = ProjektPhaseSerializer.new(@projekt_phase, current_api_client: current_client).serialize

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
    key = params.dig(:projekt_phase_setting, :key).to_s
    value = params.dig(:projekt_phase_setting, :value)

    if key.blank?
      return render json: { error: { messages: ["name is required"] } }, status: 422
    end

    configurable_keys = ProjektPhaseSetting::ConfigurableKeys.for_phase(@projekt_phase)

    if !configurable_keys.key?(key)
      return render json: { error: { messages: ["Setting not found"] } }, status: 404
    end

    result = ConfigurableKeys::UpdateService.call(
      changes: { key => value },
      configurable_keys:,
      setting_rows: @projekt_phase.settings
    )

    if result.success?
      setting = @projekt_phase.settings.find_by!(key:)

      render json: { data: { projekt_phase_setting: setting.as_json(only: [:id, :key, :value]) } }
    else
      render json: { error: { messages: result.error_details[key] } }, status: 422
    end
  end

  # All or nothing: when one key is unknown or one value has the wrong type,
  # no setting is written and every problem is listed under errors.
  def update_settings
    check_admin_access!
    settings_hash = params[:settings]

    if !settings_hash.is_a?(ActionController::Parameters) || settings_hash.blank?
      return render json: { error: { messages: ["settings parameter is required"] } }, status: 422
    end

    result = ConfigurableKeys::UpdateService.call(
      changes: settings_hash.to_unsafe_h,
      configurable_keys: ProjektPhaseSetting::ConfigurableKeys.for_phase(@projekt_phase),
      setting_rows: @projekt_phase.settings
    )

    if result.success?
      render json: { data: { updated: result.data[:values].keys, errors: {} } }
    else
      render json: { data: { updated: [], errors: result.error_details } }
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

  def public_phase?(projekt_phase)
    projekt_phase.frontend_visibility && projekt_phase.active? && projekt_phase.projekt.visible_for?(nil)
  end

  def render_access_denied
    render json: { error: { type: "forbidden", messages: ["Access denied"] }}, status: :forbidden
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

