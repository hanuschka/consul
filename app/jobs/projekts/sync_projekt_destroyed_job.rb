class Projekts::SyncProjektDestroyedJob < ApplicationJob
  queue_as :default

  def perform(projekt_id)
    DtApi::Client.new.projekts.destroyed(projekt_id)
  end
end
