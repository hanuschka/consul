class Projekts::OverviewProjektUpdatedJob < ApplicationJob
  queue_as :default

  def perform(projekt)
    serialized_projekt = Projekts::SerializeForOverview.call(projekt)

    DtApi.new(ApiClient.dt.service_api_token).projekt_updated(projekt.id, serialized_projekt)
  end
end
