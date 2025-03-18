class Projekts::OverviewProjektDestroyedJob < ApplicationJob
  queue_as :default

  def perform(projekt_id)
    DtApi.new.projekt_destroyed(projekt_id)
  end
end
