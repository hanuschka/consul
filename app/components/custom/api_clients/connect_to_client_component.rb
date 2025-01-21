class ApiClients::ConnectToClientComponent < ApplicationComponent
  def render?
    ApiClient.active_dt? && Rails.application.secrets.dt[:enabled] && !current_user.on_dt?
  end
end
