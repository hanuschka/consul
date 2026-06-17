require_dependency Rails.root.join("app", "models", "map_location").to_s

class MapLocation < ApplicationRecord
  def self.proposal_features(proposal_ids)
    return [] if proposal_ids.blank?

    rows = where(mappable_type: "Proposal", mappable_id: proposal_ids)
      .joins("INNER JOIN proposals ON proposals.id = map_locations.mappable_id")
      .joins("LEFT JOIN masterportal_pins ON masterportal_pins.id = proposals.masterportal_pin_id")
      .order("map_locations.id")
      .pluck("map_locations.id", "map_locations.features", "masterportal_pins.id")

    regular_ids = rows.reject { |_id, _features, masterportal_pin_id| masterportal_pin_id.present? }.map(&:first)
    regular_features = regular_proposal_features(regular_ids)

    rows.map do |map_location_id, features, masterportal_pin_id|
      if masterportal_pin_id.present?
        masterportal_pin_feature_collection(features, masterportal_pin_id)
      else
        regular_features[map_location_id]
      end
    end
  end

  def self.regular_proposal_features(map_location_ids)
    return {} if map_location_ids.blank?

    where(id: map_location_ids)
      .includes(mappable: [:projekt_labels, :sentiment, :masterportal_pin])
      .index_by(&:id)
      .transform_values(&:features_json_data)
  end

  def self.masterportal_pin_feature_collection(features, masterportal_pin_id)
    feature_collection = normalize_feature_collection(features)
    properties = { "resource_type" => "masterportal_pin", "id" => masterportal_pin_id }

    feature_collection["features"].each do |feature|
      feature["properties"].merge!(properties)
    end

    feature_collection
  end

  def self.normalize_feature_collection(features)
    features = JSON.parse(features) if features.is_a?(String)

    if features.is_a?(Hash) && features["type"] == "FeatureCollection"
      features
    elsif features.is_a?(Hash) && features["type"] == "Feature"
      { "type" => "FeatureCollection", "features" => [features] }
    else
      { "type" => "FeatureCollection", "features" => [] }
    end
  rescue JSON::ParserError
    { "type" => "FeatureCollection", "features" => [] }
  end

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
