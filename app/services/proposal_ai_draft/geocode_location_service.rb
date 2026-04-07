class ProposalAiDraft::GeocodeLocationService < ApplicationService
  def initialize(proposal:, location_name:)
    @proposal = proposal
    @location_name = location_name
  end

  def call
    geo_result = Geocoder.search(@location_name).first
    return unless geo_result.present?

    lat, lng = geo_result.coordinates
    zoom = @proposal.projekt_phase.map_location&.zoom || 15

    MapLocation.create!(
      mappable: @proposal,
      latitude: lat,
      longitude: lng,
      zoom:,
      features: build_features(lat, lng)
    )
  rescue StandardError => e
    Rails.logger.error("[ProposalAiDraft] GeocodeLocationService failed: #{e.message}")
  end

  private

    def build_features(lat, lng)
      {
        "type" => "FeatureCollection",
        "features" => [{
          "type" => "Feature",
          "geometry" => {
            "type" => "Point",
            "coordinates" => [lng, lat]
          },
          "properties" => {}
        }]
      }
    end
end
