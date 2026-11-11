class InternalApi::ProjektSettingsController < InternalApi::BaseController
  before_action :find_projekt
  around_action :audit_changes_as_internal_client

  skip_authorization_check

  # Written through the typed allowlist of the projekt's settings. `update`,
  # not `update_column`, inside it: a promoted setting mirrors its value onto
  # the projekts column from an after_save callback (see Projekt::KEY_TO_COLUMN).
  def update
    configurable_keys = ProjektSetting::ConfigurableKeys.for_projekt(@projekt)
    key = projekt_setting_params[:key].to_s

    if !configurable_keys.key?(key)
      return render json: { message: "Projekt setting not found" }, status: :not_found
    end

    result = ConfigurableKeys::UpdateService.call(
      changes: { key => projekt_setting_params[:value] },
      configurable_keys:,
      setting_rows: @projekt.projekt_settings
    )

    if result.success?
      render json: { message: "Projekt setting updated" }
    else
      render_setting_errors(result.error_details)
    end
  end

  private

  def find_projekt
    @projekt = Projekt.find(params[:projekt_id])
  end

  def projekt_setting_params
    params.require(:projekt_setting).permit(
      :key, :value
    )
  end
end
