class InternalApi::SettingsController < InternalApi::BaseController
  around_action :audit_changes_as_internal_client

  def enable
    switch(true)
  end

  def disable
    switch(false)
  end

  private

    def switch(enabled)
      result = ConfigurableKeys::UpdateService.call(
        changes: { params[:name].to_s => enabled },
        configurable_keys: Setting::ConfigurableKeys.internal_switches,
        setting_rows: Setting.all
      )

      if result.success?
        head :no_content
      else
        render_setting_errors(result.error_details)
      end
    end
end
