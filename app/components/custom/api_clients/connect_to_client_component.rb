class ApiClients::ConnectToClientComponent < ApplicationComponent
  def render?
    Rails.application.secrets.dt[:enabled]
  end
end
