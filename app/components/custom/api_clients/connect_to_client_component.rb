class ApiClients::ConnectToClientComponent < ApplicationComponent
  def render?
    Rails.application.secrets.dt[:enabled] && !current_user.on_dt?
  end
end
