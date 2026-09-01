class Masterportal::SourceExternalIdsService < ApplicationService
  def initialize(masterportal_collection:)
    @collection = masterportal_collection
  end

  def call
    ids = Set.new

    each_source_feature do |feature|
      external_id = Masterportal::FeaturePropertyReader.external_id(feature)
      ids << external_id if external_id.present?
    end

    ids
  end

  private

    def each_source_feature(&block)
      if @collection.file_source?
        Masterportal::GeojsonFileFeatures.new(masterportal_collection: @collection).each(&block)
      else
        OgcApiFeatures::Client.fetch_features(
          @collection.endpoint_url, @collection.collection_id, &block
        )
      end
    end
end
