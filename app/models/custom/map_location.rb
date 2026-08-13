require_dependency Rails.root.join("app", "models", "map_location").to_s

class MapLocation < ApplicationRecord
  # What a single dropped pin zooms to when the phase carries no map of its own
  # to take the scale from.
  DEFAULT_PIN_ZOOM = 15

  # The one pin a drafting flow puts on a resource: geocoded from the citizen's
  # own wording, or shared through WhatsApp's picker. Both used to assemble it
  # themselves, which made the coordinate order, the zoom fallback and the
  # replace-or-add question three things to keep in step across two namespaces.
  #
  # Updated in place rather than destroyed and re-created, because `mappable` is
  # `touch: true` and audited: replacing the row would stamp the resource twice
  # and file the citizen's correction as a deletion.
  def self.create_pin!(mappable:, latitude:, longitude:)
    pin = mappable.map_location || new(mappable: mappable)

    pin.update!(
      latitude: latitude,
      longitude: longitude,
      zoom: mappable.projekt_phase&.map_location&.zoom || DEFAULT_PIN_ZOOM,
      features: point_feature_collection(latitude: latitude, longitude: longitude)
    )

    pin
  end

  # One pin as the GeoJSON the map renderers read. Written here rather than in
  # each producer: two copies of a coordinate order are two chances to write it
  # the wrong way round.
  def self.point_feature_collection(latitude:, longitude:)
    {
      "type" => "FeatureCollection",
      "features" => [{
        "type" => "Feature",
        "geometry" => {
          "type" => "Point",
          "coordinates" => [longitude.to_f, latitude.to_f]
        },
        "properties" => {}
      }]
    }
  end

  def self.proposal_features(proposal_ids)
    return [] if proposal_ids.blank?

    rows = where(mappable_type: "Proposal", mappable_id: proposal_ids)
      .joins("INNER JOIN proposals ON proposals.id = map_locations.mappable_id")
      .joins("LEFT JOIN masterportal_pins ON masterportal_pins.id = proposals.masterportal_pin_id")
      .order("map_locations.id")
      .pluck("map_locations.id", "map_locations.features", "masterportal_pins.id", "masterportal_pins.properties")

    regular_ids = rows.reject { |_id, _features, masterportal_pin_id, _pin_properties| masterportal_pin_id.present? }.map(&:first)
    regular_features = regular_proposal_features(regular_ids)

    rows.map do |map_location_id, features, masterportal_pin_id, pin_properties|
      if masterportal_pin_id.present?
        masterportal_pin_feature_collection(features, masterportal_pin_id, pin_properties)
      else
        regular_features[map_location_id]
      end
    end
  end

  def self.deficiency_report_features(deficiency_report_ids)
    return [] if deficiency_report_ids.blank?

    unicode_cache = awesome_icon_unicode_cache

    rows = where(mappable_type: "DeficiencyReport", mappable_id: deficiency_report_ids)
      .joins(
        "INNER JOIN deficiency_reports " \
        "ON deficiency_reports.id = map_locations.mappable_id"
      )
      .joins(
        "LEFT JOIN deficiency_report_categories " \
        "ON deficiency_report_categories.id = deficiency_reports.deficiency_report_category_id"
      )
      .order("map_locations.id")
      .pluck(
        "map_locations.mappable_id",
        "map_locations.features",
        "deficiency_report_categories.color",
        "deficiency_report_categories.icon"
      )

    rows.map do |mappable_id, features, color, icon|
      feature_collection = normalize_feature_collection(features)

      extra_properties = {
        "resource_type" => RESOURCE_TYPE_MAPPING[:DeficiencyReport],
        "id" => mappable_id,
        "feature_color" => color,
        "feature_icon_name" => icon,
        "feature_icon_unicode" => unicode_cache[icon]
      }.reject { |_key, value| value.in?([nil, ""]) }

      feature_collection["features"].each do |feature|
        feature["properties"] ||= {}
        feature["properties"].merge!(extra_properties)
      end

      feature_collection
    end
  end

  def self.regular_proposal_features(map_location_ids)
    return {} if map_location_ids.blank?

    where(id: map_location_ids)
      .includes(mappable: [{ projekt_labels: :masterportal_collection }, :sentiment, :masterportal_pin])
      .index_by(&:id)
      .transform_values(&:features_json_data)
  end

  def self.masterportal_pin_feature_collection(features, masterportal_pin_id, pin_properties)
    feature_collection = normalize_feature_collection(features)
    properties = { "resource_type" => "masterportal_pin", "id" => masterportal_pin_id }

    icon_url = MasterportalPin.icon_url_from_properties(pin_properties)
    properties["feature_icon_url"] = icon_url if icon_url.present?

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

  def self.flatten_feature_collections(items)
    features = Array(items).flat_map do |item|
      next [] if item.blank?

      if item["type"] == "FeatureCollection"
        item["features"] || []
      elsif item["type"] == "Feature"
        [item]
      else
        []
      end
    end

    { "type" => "FeatureCollection", "features" => features }
  end

  def self.enriched_feature_collection(map_locations, category_icons: nil, extra_features: [])
    map_locations = map_locations.to_a

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
