require_dependency Rails.root.join("app", "models", "map_location").to_s

class MapLocation < ApplicationRecord
  def self.enriched_feature_collection(map_locations, category_icons: nil, extra_features: [])
    icon_names = map_locations.flat_map do |ml|
      ml.to_geo_json["features"].map do |f|
        f["properties"]["feature_icon_name"] || f["properties"]["fa_icon_class"]
      end
    end.compact.uniq

    icon_unicodes = AwesomeIcon.where(name: icon_names).pluck(:name, :unicode).to_h

    features = map_locations.flat_map do |ml|
      enriched = ml.to_geo_json["features"].map do |f|
        icon_name = f["properties"]["feature_icon_name"] || f["properties"]["fa_icon_class"]
        f.merge("properties" => f["properties"].merge(
          "resource_type" => RESOURCE_TYPE_MAPPING[ml.mappable_type.to_sym],
          "id" => ml.mappable_id,
          "feature_icon_unicode" => icon_unicodes[icon_name]
        ))
      end

      if category_icons.present?
        enriched.select do |f|
          f["properties"]["feature_icon_name"].in?(category_icons) ||
            f["properties"]["fa_icon_class"].in?(category_icons)
        end
      else
        enriched
      end
    end

    features += extra_features if extra_features.present?

    {
      type: "FeatureCollection",
      features: features
    }
  end
end
