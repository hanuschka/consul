class MasterportalImportJob < ApplicationJob
  queue_as :default

  def perform(
    projekt_phase_id:,
    endpoint_url: nil,
    collection_ids: [],
    uploaded_collection_ids: [],
    create_domain_records:,
    triggered_by_user_id: nil
  )
    projekt_phase = ProjektPhase.find(projekt_phase_id)
    triggered_by = triggered_by_user_id.present? ? User.find(triggered_by_user_id) : nil

    Masterportal::ImportService.call(
      projekt_phase: projekt_phase,
      endpoint_url: endpoint_url,
      collection_ids: collection_ids,
      uploaded_collection_ids: uploaded_collection_ids,
      create_domain_records: create_domain_records,
      triggered_by_user: triggered_by
    )
  end
end
