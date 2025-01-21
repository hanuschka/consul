class ApiClients::ConnectToClientComponent < ApplicationComponent
  def render?
    ApiClient.active_dt? && Rails.application.secrets.dt[:enabled]
  end
end
