class MapBoundary
  def initialize(area_features)
    @area_features = area_features
  end

  def restricted?
    areas.any?
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

    areas.any? { |area| area.intersects?(point) }
  end

  def contains_features?(features)
    return true unless restricted?

    decode(features).all? { |geometry| geometry.difference(union).empty? }
  rescue RGeo::Error::RGeoError
    false
  end

  private

    def areas
      @areas ||= decode(@area_features).filter_map { |geometry| usable_area(geometry) }
    rescue RGeo::Error::InvalidGeometry
      @areas = []
    end

    def usable_area(geometry)
      return nil unless geometry.dimension == 2
      return geometry if geometry.invalid_reason.nil?

      repaired = geometry.make_valid

      repaired if repaired.dimension == 2
    rescue RGeo::Error::RGeoError
      nil
    end

    def union
      @union ||= factory.collection(areas).unary_union
    end

    def decode(features)
      RGeo::GeoJSON
        .decode(feature_collection(features), json_parser: :json, geo_factory: factory)
        .map(&:geometry)
        .compact
    end

    def feature_collection(features)
      return { "type" => "FeatureCollection", "features" => [] } unless features.is_a?(Hash)

      case features["type"]
      when "FeatureCollection" then features
      when "Feature" then { "type" => "FeatureCollection", "features" => [features] }
      else { "type" => "FeatureCollection", "features" => [] }
      end
    end

    def factory
      @factory ||= RGeo::Geos.factory
    end
end
