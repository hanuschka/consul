class ProposalAiDraft::GeocodeLocationService < ApplicationService
  PROJEKT_AREA_HALF_EXTENT_DEGREES = 0.5

  # Any mappable the drafting flows produce — a Proposal on the web and either a
  # Proposal or a Budget::Investment over WhatsApp, which is why the keyword no
  # longer names one of them.
  def initialize(mappable:, location_name:)
    @mappable = mappable
    @location_name = location_name
  end

  def call
    geo_result = search_biased_to_projekt_area
    return if geo_result.blank?

    lat, lng = geo_result.coordinates

    MapLocation.create_pin!(mappable: @mappable, latitude: lat, longitude: lng)
  rescue StandardError => e
    Rails.logger.error("[ProposalAiDraft] GeocodeLocationService failed: #{e.message}")
  end

  private

    def search_biased_to_projekt_area
      center = projekt_phase_map_location

      if center&.latitude.present? && center&.longitude.present?
        Geocoder.search(@location_name, params: viewbox_params(center)).first
      else
        Geocoder.search(@location_name).first
      end
    end

    def projekt_phase_map_location
      @projekt_phase_map_location ||= @mappable.projekt_phase&.map_location
    end

    def viewbox_params(center)
      lat = center.latitude.to_f
      lng = center.longitude.to_f
      delta = PROJEKT_AREA_HALF_EXTENT_DEGREES

      {
        viewbox: "#{lng - delta},#{lat - delta},#{lng + delta},#{lat + delta}",
        bounded: 1
      }
    end
end
