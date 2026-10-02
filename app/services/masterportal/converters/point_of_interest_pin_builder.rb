class Masterportal::Converters::PointOfInterestPinBuilder < ApplicationService
  def initialize(masterportal_pin:)
    @pin = masterportal_pin
  end

  def call
    poi_pin = ProjektPointOfInterestPin.new(
      projekt_phase: @pin.projekt_phase,
      author: User.system,
      description: description_with_title,
      masterportal_pin_id: @pin.id
    )

    poi_pin.map_location = build_map_location

    poi_pin
  end

  private

    def description_with_title
      title = @pin.title.to_s.presence || @pin.external_id
      body = @pin.description.to_s.presence

      [title, body].compact.join("\n\n")
    end

    def build_map_location
      MapLocation.new(
        latitude: @pin.latitude,
        longitude: @pin.longitude,
        zoom: default_zoom,
        features: MapLocation.point_feature_collection(
          latitude: @pin.latitude, longitude: @pin.longitude
        ),
        geocoder_data: Masterportal::GeocoderDataBuilder.call(pin: @pin),
        skip_masterportal_geocoding: true
      )
    end

    def default_zoom
      Setting["map.zoom"].presence || 10
    end
end
