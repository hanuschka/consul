class Api::Configuration::SettingsController < Api::Configuration::BaseController
  def index
    configurable_keys = filtered_configurable_keys
    stored_values = Setting.where(key: configurable_keys.map(&:key)).pluck(:key, :value).to_h

    render json: {
      data: {
        settings: configurable_keys.map { |configurable_key| serialize(configurable_key, stored_values) }
      }
    }
  end

  def update
    result = ConfigurableKeys::UpdateService.call(
      changes: settings_param,
      configurable_keys: Setting::ConfigurableKeys.all,
      setting_rows: Setting.all
    )

    if result.success?
      render json: { data: { settings: result.data[:values] } }
    else
      render_invalid_values(result.error_details)
    end
  end

  private

    def filtered_configurable_keys
      configurable_keys = Setting::ConfigurableKeys.all.values

      if params[:group].present?
        configurable_keys.select { |configurable_key| configurable_key.group == params[:group].to_s }
      else
        configurable_keys
      end
    end

    def serialize(configurable_key, stored_values)
      {
        key: configurable_key.key,
        group: configurable_key.group,
        type: configurable_key.type,
        options: configurable_key.options.presence,
        allow_blank: configurable_key.value_definition.allow_blank,
        value: configurable_key.from_storage(stored_values[configurable_key.key])
      }.compact
    end

    # Keys are free-form here on purpose: each one is checked against
    # Setting::ConfigurableKeys and its value against the key's type.
    def settings_param
      settings = params.require(:settings)

      if settings.is_a?(ActionController::Parameters)
        settings.to_unsafe_h
      else
        raise ActionController::ParameterMissing, :settings
      end
    end
end
