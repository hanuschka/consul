class Adm::MasterportalCollectionsListComponent < ApplicationComponent
  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def render?
    collections.any?
  end

  def collections
    @collections ||= @projekt_phase.masterportal_collections.ordered
  end

  def update_url(collection)
    helpers.update_masterportal_collection_adm_projekts_phase_path(
      @projekt_phase, masterportal_collection_id: collection.id
    )
  end

  def delete_url(collection)
    helpers.destroy_masterportal_collection_adm_projekts_phase_path(
      @projekt_phase, masterportal_collection_id: collection.id
    )
  end

  def status_url(collection)
    helpers.masterportal_collection_status_adm_projekts_phase_path(
      @projekt_phase, masterportal_collection_id: collection.id
    )
  end

  def diff_url(collection)
    helpers.masterportal_collection_diff_adm_projekts_phase_path(
      @projekt_phase, masterportal_collection_id: collection.id
    )
  end

  def clean_url(collection)
    helpers.clean_masterportal_collection_stale_pins_adm_projekts_phase_path(
      @projekt_phase, masterportal_collection_id: collection.id
    )
  end
end
