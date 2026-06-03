class Geo::BoundingBox
  EARTH_KM_PER_DEGREE = 111.12

  def initialize(latitude:, longitude:, radius_km:)
    @latitude = latitude
    @longitude = longitude
    @radius_km = radius_km
  end

  def to_a
    [min_longitude, min_latitude, max_longitude, max_latitude]
  end

  private

  def radius_latitude
    @radius_km / EARTH_KM_PER_DEGREE
  end

  def radius_longitude
    @radius_km / (EARTH_KM_PER_DEGREE * Math.cos(@latitude * Math::PI / 180))
  end

  def min_latitude
    @latitude - radius_latitude
  end

  def max_latitude
    @latitude + radius_latitude
  end

  def min_longitude
    @longitude - radius_longitude
  end

  def max_longitude
    @longitude + radius_longitude
  end
end
