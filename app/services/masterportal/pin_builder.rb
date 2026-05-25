class Masterportal::PinBuilder < ApplicationService
  def initialize(projekt_phase:, endpoint_url:, collection_id:, feature:)
    @projekt_phase = projekt_phase
    @endpoint_url = endpoint_url
    @collection_id = collection_id
    @feature = feature
  end

  def call
    external_id = Masterportal::FeaturePropertyReader.external_id(@feature)

    pin = MasterportalPin.find_or_initialize_by(
      projekt_phase_id: @projekt_phase.id,
      external_id: external_id
    )

    pin.endpoint_url = @endpoint_url
    pin.collection_id = @collection_id
    pin.title = Masterportal::FeaturePropertyReader.title(@feature)
    pin.description = Masterportal::FeaturePropertyReader.description(@feature)
    pin.latitude = Masterportal::FeaturePropertyReader.latitude(@feature)
    pin.longitude = Masterportal::FeaturePropertyReader.longitude(@feature)
    pin.properties = @feature["properties"] || {}
    pin.raw_feature = @feature
    pin.last_imported_at = Time.current

    pin
  end
end
