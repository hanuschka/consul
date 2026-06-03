class Adm::MasterportalCollectionCardComponent < ApplicationComponent
  with_collection_parameter :collection

  attr_reader :collection, :projekt_phase

  def initialize(collection:, projekt_phase:)
    @collection = collection
    @projekt_phase = projekt_phase
  end

  def update_url
    helpers.update_masterportal_collection_adm_projekts_phase_path(
      projekt_phase, masterportal_collection_id: collection.id
    )
  end

  def delete_url
    helpers.destroy_masterportal_collection_adm_projekts_phase_path(
      projekt_phase, masterportal_collection_id: collection.id
    )
  end

  def status_url
    helpers.masterportal_collection_status_adm_projekts_phase_path(
      projekt_phase, masterportal_collection_id: collection.id
    )
  end

  def diff_url
    helpers.masterportal_collection_diff_adm_projekts_phase_path(
      projekt_phase, masterportal_collection_id: collection.id
    )
  end

  def clean_url
    helpers.clean_masterportal_collection_stale_pins_adm_projekts_phase_path(
      projekt_phase, masterportal_collection_id: collection.id
    )
  end

  def card_url
    helpers.masterportal_collection_card_adm_projekts_phase_path(
      projekt_phase, masterportal_collection_id: collection.id
    )
  end
end
