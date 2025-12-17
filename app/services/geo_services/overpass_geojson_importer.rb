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
      map_location.update_column(:features, format_geojson(features))
    end

    private

      def load_geojson
        raise StandardError, "GeoJSON file not found at #{@geojson_path}" unless File.exist?(@geojson_path)

        geojson = JSON.parse(File.read(@geojson_path))

        unless geojson["generator"] == "overpass-turbo"
          raise StandardError, "Invalid GeoJSON source"
        end

        geojson
      rescue JSON::ParserError
        raise StandardError, "Invalid JSON format in GeoJSON file"
      end

      def format_geojson(features)
        selected_features = features.select do |feature|
          feature["geometry"]["type"] == "Polygon" || feature["geometry"]["type"] == "MultiPolygon"
        end

        {
          type: "FeatureCollection",
          features: selected_features
        }
      end
  end
end
