class Masterportal::CollectionDiffService < ApplicationService
  def initialize(masterportal_collection:)
    @collection = masterportal_collection
  end

  def call
    source_ids = Masterportal::SourceExternalIdsService.call(masterportal_collection: @collection)
    stored_ids = stored_external_ids

    {
      source_count: source_ids.size,
      stored_count: stored_ids.size,
      new_count: (source_ids - stored_ids).size,
      stale_count: (stored_ids - source_ids).size
    }
  end

  private

    def stored_external_ids
      @collection.masterportal_pins.pluck(:external_id).compact.to_set
    end
end
