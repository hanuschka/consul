class InternalApi::SettingsController < InternalApi::BaseController
  def enable
    Setting[params[:name]] = true
  end

  def disable
    Setting[params[:name]] = false
  end
end
