class Projekts::OverviewProjektUpdatedJob < ApplicationJob
  queue_as :default

  def perform(projekt)
    serialized_projekt = Projekts::SerializeForOverview.call(projekt)

    DtApi::Client.new.projekts.updated(projekt.id, serialized_projekt)

    projekt.update_column(:on_dt_global_overview, true)
  end
end
