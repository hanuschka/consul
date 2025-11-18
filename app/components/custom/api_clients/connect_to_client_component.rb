class ApiClients::ConnectToClientComponent < ApplicationComponent
  def render?
    Dt.enabled?
  end
end
