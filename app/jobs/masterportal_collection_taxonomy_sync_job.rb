class MasterportalCollectionTaxonomySyncJob < ApplicationJob
  queue_as :default

  def perform(projekt_phase_id:)
    projekt_phase = ProjektPhase.find_by(id: projekt_phase_id)
    return if projekt_phase.nil?

    Masterportal::CollectionTaxonomySyncService.call(projekt_phase: projekt_phase)
  end
end
