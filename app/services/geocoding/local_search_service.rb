class Geocoding::LocalSearchService < ApplicationService
  DEFAULT_RADIUS_KM = 20.0

  def initialize(query:, latitude: nil, longitude: nil, radius_km: DEFAULT_RADIUS_KM, limit: nil)
    @query = query
    @latitude = latitude
    @longitude = longitude
    @radius_km = radius_km
    @limit = limit
  end

  def call
    return [] if @query.blank?

    results = Geocoder.search(@query, params: extra_query_params)

    @limit.present? ? results.first(@limit) : results
  end

  private

  def extra_query_params
    return {} if Geocoder.config[:lookup] != :nominatim

    { viewbox: bounding_box_coordinates.join(","), bounded: 1 }
  end

  def bounding_box_coordinates
    Geo::BoundingBox.new(
      latitude: center_latitude,
      longitude: center_longitude,
      radius_km: @radius_km
    ).to_a
  end

  def center_latitude
    (@latitude.presence || Setting["map.latitude"]).to_f
  end

  def center_longitude
    (@longitude.presence || Setting["map.longitude"]).to_f
  end
end
