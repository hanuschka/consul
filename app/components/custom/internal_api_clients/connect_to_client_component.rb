class InternalApiClients::ConnectToClientComponent < ApplicationComponent
  def render?
    Dt.enabled? && !InternalApiClient.dt_connected?
  end
end
