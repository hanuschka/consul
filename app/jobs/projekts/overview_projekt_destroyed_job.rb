class Projekts::OverviewProjektDestroyedJob < ApplicationJob
  queue_as :default

  def perform(projekt_id)
    DtApi.new(ApiClient.dt.service_api_token).projekt_destroyed(projekt_id)
  end
end
