class Masterportal::PinBuilder < ApplicationService
  def initialize(
    projekt_phase:,
    endpoint_url:,
    collection_id:,
    feature:,
    collection_title: nil,
    masterportal_collection: nil
  )
    @projekt_phase = projekt_phase
    @endpoint_url = endpoint_url
    @collection_id = collection_id
    @feature = feature
    @collection_title = collection_title
    @masterportal_collection = masterportal_collection
  end

  def call
    external_id = Masterportal::FeaturePropertyReader.external_id(@feature)

    pin = MasterportalPin.find_or_initialize_by(
      projekt_phase_id: @projekt_phase.id,
      external_id: external_id
    )

    pin.endpoint_url = @endpoint_url
    pin.collection_id = @collection_id
    pin.collection_title = @collection_title
    pin.masterportal_collection = @masterportal_collection
    pin.description = Masterportal::FeaturePropertyReader.description(@feature)
    pin.latitude = Masterportal::FeaturePropertyReader.latitude(@feature)
    pin.longitude = Masterportal::FeaturePropertyReader.longitude(@feature)
    pin.geometry = Masterportal::FeaturePropertyReader.geometry(@feature)
    pin.properties = @feature["properties"] || {}
    pin.raw_feature = @feature
    pin.last_imported_at = Time.current
    pin.title = resolved_title(pin)

    pin
  end

  private

    def resolved_title(pin)
      Masterportal::FeaturePropertyReader.title_value(@feature).presence ||
        Masterportal::CategoryNameResolver.call(pin: pin)
    end
end
