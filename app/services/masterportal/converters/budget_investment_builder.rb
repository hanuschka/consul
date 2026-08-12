class Masterportal::Converters::BudgetInvestmentBuilder < ApplicationService
  def initialize(masterportal_pin:)
    @pin = masterportal_pin
  end

  def call
    fallback_title = default_title
    budget = @pin.projekt_phase.budget
    heading = budget&.heading
    raw_title = @pin.title.to_s.presence || fallback_title
    title = raw_title.length >= 4 ? raw_title.truncate(Budget::Investment.title_max_length) : fallback_title

    investment = Budget::Investment.new(
      author: User.system,
      budget: budget,
      heading: heading,
      title: title,
      description: I18n.t("masterportal.imported_resource_description"),
      masterportal_pin_id: @pin.id
    )
    investment.resource_terms = "1"
    investment.map_location = build_map_location

    investment
  end

  private

    def default_title
      I18n.t(
        "masterportal.imported_investment_default_title",
        external_id: @pin.external_id,
        default: "Imported point %{external_id}"
      )
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
