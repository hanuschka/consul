class Polls::MapPointBoundary
  def initialize(question)
    @question = question
  end

  def restricted?
    polygons.any?
  end

  def contains?(latitude, longitude)
    return true unless restricted?

    point = factory.point(longitude.to_f, latitude.to_f)

    polygons.any? { |polygon| polygon.intersects?(point) }
  end

  private

    attr_reader :question

    def polygons
      @polygons ||= decoded_geometries.select { |geometry| geometry.dimension == 2 }
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
