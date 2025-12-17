module GeoServices
  class OverpassGeojsonImporter < ApplicationService
    def initialize(map_location_id, geojson_path)
      @map_location_id = map_location_id
      @geojson_path = geojson_path
    end

    def call
      geojson = load_geojson
      features = geojson.fetch("features")
      map_location = MapLocation.find(@map_location_id)
      lng, lat = parse_center(features)
      map_location.update!(
        latitude: lat,
        longitude: lng,
        features: format_geojson(features)
      )
    end

    private

      def load_geojson
        raise StandardError, "GeoJSON file not found at #{@geojson_path}" unless File.exist?(@geojson_path)

        geojson = JSON.parse(File.read(@geojson_path))

        unless geojson["generator"] == "overpass-turbo" && geojson["features"].size == 2
          raise StandardError, "Invalid GeoJSON source"
        end

        geojson
      rescue JSON::ParserError
        raise StandardError, "Invalid JSON format in GeoJSON file"
      end

      def parse_center(features)
        point_feature = features.find { |feature| feature.dig("geometry", "type") == "Point" }
        point_feature.dig("geometry", "coordinates")
      end

      def format_geojson(features)
        {
          type: "FeatureCollection",
          features: features
        }
      end
  end
end
