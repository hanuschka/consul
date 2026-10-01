class Masterportal::Converters::ProposalBuilder < ApplicationService
  def initialize(masterportal_pin:)
    @pin = masterportal_pin
  end

  def call
    fallback_title = default_title

    raw_title = @pin.title.to_s.presence || fallback_title
    title = raw_title.length >= 4 ? raw_title.truncate(Proposal.title_max_length) : fallback_title

    proposal = Proposal.new(
      author: User.system,
      projekt_phase: @pin.projekt_phase,
      title: title,
      description: I18n.t("masterportal.imported_resource_description"),
      summary: title,
      masterportal_pin_id: @pin.id,
      published_at: Time.current
    )
    proposal.resource_terms = "1"
    proposal.map_location = build_map_location

    proposal
  end

  private

    def default_title
      I18n.t(
        "masterportal.imported_proposal_default_title",
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
