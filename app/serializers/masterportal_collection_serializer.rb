# Import and removal state, errors and counts are the platform's own
# bookkeeping and the uploaded GeoJSON file is never exposed.
class MasterportalCollectionSerializer < BaseSerializer
  def initialize(masterportal_collection, client: nil)
    @masterportal_collection = masterportal_collection
    @client = client
  end

  def serialize
    collection_data = {
      id: masterportal_collection.id,
      projekt_phase_id: masterportal_collection.projekt_phase_id,
      collection_id: masterportal_collection.collection_id,
      name: masterportal_collection.name,
      source: masterportal_collection.source,
      icon_url: masterportal_collection.icon_url,
      feature_color: masterportal_collection.feature_color,
      contains_shapes: masterportal_collection.contains_shapes,
      has_default_icon_pins: masterportal_collection.has_default_icon_pins,
      last_imported_at: masterportal_collection.last_imported_at
    }

    if admin_client?
      collection_data.merge!(
        endpoint_url: masterportal_collection.endpoint_url,
        create_domain_records: masterportal_collection.create_domain_records
      )
    end

    collection_data
  end

  private

    attr_reader :masterportal_collection
end
