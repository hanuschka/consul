class Api::IframesController < Api::BaseController
  before_action :find_projekt_phase, only: [:show, :update]
  around_action :audit_changes_as_client, only: [:update]

  def show
    check_read_access!
    serialized_iframe = IframeSerializer.new(@projekt_phase).serialize

    render json: { data: { iframe: serialized_iframe } }
  end

  # All or nothing, typed like the phase settings: the URL must be http(s),
  # width and height whole numbers; each may be cleared with "".
  def update
    check_admin_access!

    result = ConfigurableKeys::UpdateService.call(
      changes: iframe_setting_changes,
      configurable_keys: iframe_configurable_keys,
      setting_rows: @projekt_phase.settings
    )

    if !result.success?
      return render_invalid_values(iframe_attribute_errors(result.error_details))
    end

    serialized_iframe = IframeSerializer.new(@projekt_phase.reload).serialize

    render json: { data: { iframe: serialized_iframe } }
  end

  private

  def iframe_params
    params.require(:projekt_iframe).permit(*IframeSerializer::SETTING_KEYS.keys)
  end

  def iframe_setting_changes
    iframe_params.to_h.to_h do |attribute, value|
      [IframeSerializer::SETTING_KEYS.fetch(attribute.to_sym), value]
    end
  end

  def iframe_configurable_keys
    ProjektPhaseSetting::ConfigurableKeys
      .for_phase(@projekt_phase)
      .slice(*IframeSerializer::SETTING_KEYS.values)
  end

  def iframe_attribute_errors(errors_by_setting_key)
    errors_by_setting_key.transform_keys { IframeSerializer::SETTING_KEYS.key(it).to_s }
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::IframePhase.find(params[:projekt_phase_id])
  end
end
