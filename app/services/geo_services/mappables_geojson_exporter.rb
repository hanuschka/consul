module GeoServices
  class MappablesGeojsonExporter < ApplicationService
    def initialize(mappables)
      @mappables = mappables
    end

    def call
      JSON.generate(
        "type" => "FeatureCollection",
        "features" => collect_features
      )
    end

    private

      def collect_features
        @mappables.includes(:map_location).flat_map do |mappable|
          mappable.map_location&.features_json_data&.dig("features") || []
        end
      end
  end
end
