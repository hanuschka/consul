class ApiClients::ConnectToClientComponent < ApplicationComponent
  def render?
    Rails.application.secrets.dt[:enabled]
  end

  def show_navigate_to_dt_link?
    ApiClient.active_dt? && current_user.on_dt?
  end
end
