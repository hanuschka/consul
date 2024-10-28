class Api::SettingsController < Api::BaseController
  skip_forgery_protection

  def enable
    Setting[params[:name]] = true
  end

  def disable
    Setting[params[:name]] = false
  end
end
