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
          "category_name",
          "address",
          "latitude",
          "longitude",
          "created_at"
        ]
      end

      def row(pin)
        [
          pin.id,
          pin.projekt_point_of_interest_category.name,
          pin.map_location.get_approximated_address,
          geo_field(pin.map_location.latitude),
          geo_field(pin.map_location.longitude),
          pin.created_at
        ]
      end

      def geo_field(field)
        return nil if field.blank?

        "\"#{field}\""
      end
  end
end
