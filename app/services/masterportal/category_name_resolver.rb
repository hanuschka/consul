class Masterportal::CategoryNameResolver < ApplicationService
  def initialize(pin:)
    @pin = pin
  end

  def call
    from_properties || @pin.collection_title.presence || humanized_collection_id
  end

  private

    def from_properties
      Masterportal::FeaturePropertyReader.category_name(@pin.raw_feature || {})
    end

    def humanized_collection_id
      @pin.collection_id.to_s.humanize.presence
    end
end
