module CsvServices
  class BaseService < ApplicationService
    include ActionView::Helpers::NumberHelper

    def sanitize_for_csv(value)
      value.to_s.gsub(/^[=+@-]/, "^")
    end

    def strip_tags(html_string)
      ActionView::Base.full_sanitizer.sanitize(html_string)
    end

    def geo_field(field)
      return nil if field.blank?

      "\"#{field}\""
    end

    def format_geometry(geojson)
      return "" if geojson.blank?

      if geojson["type"] == "FeatureCollection"

        features = geojson["features"].map do |feature|
          geometry = feature["geometry"]
          "#{geometry["type"]}: #{geometry["coordinates"].flatten.join(", ")}"
        end
        features.join(" | ")
      elsif geojson["type"] == "Feature"
        geometry = geojson["geometry"]
        "#{geometry["type"]}: #{geometry["coordinates"].flatten.join(", ")}"
      else
        ""
      end
    end
  end
end
