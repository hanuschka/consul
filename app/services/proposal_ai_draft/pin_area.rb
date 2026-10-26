class ProposalAiDraft::PinArea
  # Where a pin on a contribution to this phase may fall at all: a square around
  # the phase's own map centre, the projekt's where the phase has none, and the
  # portal's where neither has one. It used to be a half-degree box that was only
  # ever a search hint, and without a phase map no bound at all — so "am Bahnhof"
  # for a projekt in Ergersheim landed on Würzburg's main station.
  #
  # The radius is the one the portal's local place search already uses, so a
  # place typed into the map search and a place read from a citizen's words are
  # bounded alike. The check is made on the coordinates themselves rather than
  # left to the geocoder's own `bounded` option: that is a request to a service
  # that may ignore it, and "never outside" cannot rest on a request.
  RADIUS_KM = ::Geocoding::LocalSearchService::DEFAULT_RADIUS_KM

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def latitude
    center.first
  end

  def longitude
    center.last
  end

  def radius_km
    RADIUS_KM
  end

  def contains?(latitude, longitude)
    latitude.present? && longitude.present? && bounding_box.contains?(latitude, longitude)
  end

  private

    def bounding_box
      @bounding_box ||= ::Geo::BoundingBox.new(
        latitude: latitude, longitude: longitude, radius_km: radius_km
      )
    end

    def center
      @center ||= map_center(@projekt_phase&.map_location) ||
                  map_center(@projekt_phase&.projekt&.map_location) ||
                  [Setting["map.latitude"].to_f, Setting["map.longitude"].to_f]
    end

    def map_center(map_location)
      if map_location&.latitude.present? && map_location&.longitude.present?
        [map_location.latitude.to_f, map_location.longitude.to_f]
      end
    end
end
