class Masterportal::CleanStaleService < ApplicationService
  def initialize(masterportal_collection:)
    @collection = masterportal_collection
  end

  def call
    source_ids = Masterportal::SourceExternalIdsService.call(masterportal_collection: @collection)

    if source_ids.empty?
      raise OgcApiFeatures::Error, "Source returned no features; refusing to delete pins"
    end

    delete_stale_pins(source_ids)
  end

  private

    def delete_stale_pins(source_ids)
      deleted_pins_count = 0
      deleted_resources_count = 0

      @collection.masterportal_pins
        .where.not(external_id: source_ids.to_a)
        .includes(:proposal, :budget_investment, :projekt_point_of_interest_pin)
        .find_each do |pin|
          ActiveRecord::Base.transaction do
            associated = pin.associated_record

            if associated.present?
              associated.destroy!
              deleted_resources_count += 1
            end

            pin.destroy!
            deleted_pins_count += 1
          end
        end

      {
        deleted_pins_count: deleted_pins_count,
        deleted_resources_count: deleted_resources_count,
        remaining_pins_count: @collection.masterportal_pins.count
      }
    end
end
