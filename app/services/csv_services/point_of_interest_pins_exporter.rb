module CsvServices
  class PointOfInterestPinsExporter < CsvServices::BaseService
    require "csv"

    def initialize(pins)
      @pins = pins
    end

    def call
      CSV.generate(headers: true, col_sep: ";", force_quotes: true, encoding: "UTF-8") do |csv|
        csv << headers

        @pins.each do |pin|
          csv << row(pin)
        end
      end
    end

    private

      def headers
        [
          "id",
          "address",
          "created_at",
          "latitude",
          "longitude",
          "geometry"
        ]
      end

      def row(pin)
        [
          pin.id,
          pin.map_location.approximated_address,
          pin.created_at,
          geo_field(pin.map_location.latitude),
          geo_field(pin.map_location.longitude),
          format_geometry(pin.map_location&.features)
        ]
      end
  end
end
