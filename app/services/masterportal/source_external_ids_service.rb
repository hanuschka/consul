class Masterportal::SourceExternalIdsService < ApplicationService
  def initialize(endpoint_url:, collection_id:)
    @endpoint_url = endpoint_url
    @collection_id = collection_id
  end

  def call
    ids = Set.new

    OgcApiFeatures::Client.fetch_features(@endpoint_url, @collection_id) do |feature|
      external_id = Masterportal::FeaturePropertyReader.external_id(feature)
      ids << external_id if external_id.present?
    end

    ids
  end
end
