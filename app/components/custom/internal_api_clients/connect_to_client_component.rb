class InternalApiClients::ConnectToClientComponent < ApplicationComponent
  def render?
    !Dt.enabled?
  end
end
