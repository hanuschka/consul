class Polls::MapPointBoundary
  def initialize(question)
    @question = question
  end

  def restricted?
    polygons.any?
  end

  # Whether the area can be tested at all. RGeo::Geos.factory is nil wherever the
  # GEOS extension is not built, and #contains? on a restricted area then raises
  # instead of answering — so a caller that cannot afford to raise, or that would
  # rather not offer the question at all, asks this first. An unrestricted area is
  # always testable: everything is inside it.
  def usable?
    return true if !restricted?

    factory.present?
  rescue RGeo::Error::RGeoError
    false
  end

  def contains?(latitude, longitude)
    return true unless restricted?

    point = factory.point(longitude.to_f, latitude.to_f)

    polygons.any? { |polygon| polygon.intersects?(point) }
  end

  private

    attr_reader :question

    def polygons
      @polygons ||= decoded_geometries.filter_map { |geometry| usable_polygon(geometry) }
    end

    def usable_polygon(geometry)
      return nil unless geometry.dimension == 2
      return geometry if geometry.invalid_reason.nil?

      repaired = geometry.make_valid

      repaired if repaired.dimension == 2
    rescue RGeo::Error::RGeoError
      nil
    end

    def decoded_geometries
      map_location = question.map_location

      return [] if map_location.blank?

      RGeo::GeoJSON
        .decode(map_location.to_geo_json, json_parser: :json, geo_factory: factory)
        .map(&:geometry)
        .compact
    rescue RGeo::Error::InvalidGeometry
      []
    end

    def factory
      @factory ||= RGeo::Geos.factory
    end
end
