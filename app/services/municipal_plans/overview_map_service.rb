class MunicipalPlans::OverviewMapService
  AREA_GEOMETRY_TYPES = %w[Polygon MultiPolygon].freeze
  PIN_GEOMETRY_TYPES = %w[Point].freeze

  def initialize(filtered_scope, districts:, selected_district_ids:)
    @filtered_scope = filtered_scope
    @districts = districts
    @selected_district_ids = selected_district_ids.flat_map { |value| value.to_s.split(",") }.map(&:to_i)
  end

  def show?
    areas[:features].any?
  end

  def areas
    @areas ||= feature_collection(
      districts_with_map_location.flat_map do |district|
        area_geometries(district.map_location).map do |geometry|
          {
            type: "Feature",
            geometry: geometry,
            properties: {
              district_id: district.id,
              name: district.name_for_display,
              selected: district.id.in?(@selected_district_ids)
            }
          }
        end
      end
    )
  end

  def markers
    @markers ||= feature_collection(
      pinned_plans.flat_map do |plan|
        geometries(plan.map_location, PIN_GEOMETRY_TYPES).map do |geometry|
          {
            type: "Feature",
            geometry: geometry,
            properties: {
              id: plan.id,
              title: plan.title,
              url: url_helpers.municipal_plan_path(plan)
            }
          }
        end
      end
    )
  end

  private

    def districts_with_map_location
      ActiveRecord::Associations::Preloader.new.preload(@districts, :map_location)
      @districts.select(&:map_location)
    end

    def pinned_plans
      MunicipalPlan.where(id: @filtered_scope.unscope(:select, :order).select(:id))
                   .joins(:map_location)
                   .includes(:map_location, :translations)
    end

    def geometries(map_location, types)
      map_location.to_geo_json["features"].filter_map do |feature|
        geometry = feature["geometry"]
        geometry if geometry.is_a?(Hash) && geometry["type"].in?(types)
      end
    end

    def area_geometries(map_location)
      map_location.to_geo_json["features"].filter_map do |feature|
        geometry = feature["geometry"]
        next unless geometry.is_a?(Hash)
        next geometry if geometry["type"].in?(AREA_GEOMETRY_TYPES)
        next unless geometry["type"] == "GeometryCollection"

        polygon_part_geometry(Array(geometry["geometries"]))
      end
    end

    def polygon_part_geometry(parts)
      polygons = parts.flat_map do |part|
        case part["type"]
        when "Polygon" then [part["coordinates"]]
        when "MultiPolygon" then part["coordinates"]
        else []
        end
      end

      return nil if polygons.empty?
      return { "type" => "Polygon", "coordinates" => polygons.first } if polygons.one?

      { "type" => "MultiPolygon", "coordinates" => polygons }
    end

    def feature_collection(features)
      { type: "FeatureCollection", features: features }
    end

    def url_helpers
      Rails.application.routes.url_helpers
    end
end
