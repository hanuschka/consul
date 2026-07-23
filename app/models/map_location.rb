class MapLocation < ApplicationRecord
  MAP_POPUP_STANDARD_IMAGE_SIZE = [250, 170].freeze
  RESOURCE_TYPE_MAPPING = {
    Projekt: "projekt",
    ProjektPhase: "projekt_phase",
    ProjektPointOfInterestPin: "projekt_point_of_interest_pin",
    Proposal: "proposal",
    DeficiencyReport: "deficiency_report",
    Idea: "idea",
    "Budget::Investment": "investment",
    "RegisteredAddress::District": "district"
  }.freeze

  enum rendering_library: { leaflet: 0, mapbox: 1, virtualcity: 2,
                            leaflet_plus_masterportal: 3 }

  attr_accessor :skip_masterportal_geocoding

  belongs_to :mappable, polymorphic: true, touch: true
  belongs_to :district, class_name: "RegisteredAddress::District",
                        foreign_key: "registered_address_district_id",
                        optional: true,
                        inverse_of: :contained_map_locations
  has_one_attached :screenshot

  validates :longitude, :latitude, :zoom, presence: true, numericality: true

  after_initialize :set_default_values
  before_save :parse_features_string
  after_save :update_geocoder_data
  after_save :update_district

  reverse_geocoded_by :latitude, :longitude

  scope :with_deficiency_report_associations, -> {
    includes(mappable: [:category, :sentiment])
      .where(mappable_type: "DeficiencyReport")
  }

  scope :with_idea_associations, -> {
    includes(mappable: :category)
      .where(mappable_type: "Idea")
  }

  scope :with_proposal_associations, -> {
    includes(mappable: [{ projekt_labels: :masterportal_collection }, :sentiment, :masterportal_pin])
      .where(mappable_type: "Proposal")
  }

  scope :with_investment_associations, -> {
    includes(mappable: [:sentiment, { projekt_labels: :masterportal_collection }, :masterportal_pin])
      .where(mappable_type: "Budget::Investment")
  }

  scope :with_point_of_interest_pin_associations, -> {
    includes(mappable: :masterportal_pin)
      .where(mappable_type: "ProjektPointOfInterestPin")
  }

  audited associated_with: :deficiency_report,
    only: %i[features latitude longitude],
    if: :audit_changes?

  def self.default
    MapLocation.find_or_create_by!(default: true)
  end

  def self.awesome_icon_unicode_cache
    @awesome_icon_unicode_cache ||= AwesomeIcon.pluck(:name, :unicode).to_h
  end

  def available?
    latitude.present? && longitude.present? && zoom.present? || shape.present?
  end

  def map_layers
    if mappable.respond_to?(:map_layers)
      mappable.map_layers
    else
      MapLayer.default
    end
  end

  def pin_coordinates
    feature = to_geo_json["features"].first
    coords = feature&.dig("geometry", "coordinates")
    return nil if coords.blank?

    { latitude: coords[1], longitude: coords[0] }
  end

  def to_geo_json
    @geo_json ||= begin
      if features.present? && features["type"] == "FeatureCollection"
        features
      elsif features.present? && features["type"] == "Feature"
        { "type" => "FeatureCollection", "features" => [features] }
      else
        { "type" => "FeatureCollection", "features" => [] }
      end
    end
  end

  def json_data
    {
      "type" => "FeatureCollection",
      "features" => [{
        "type" => "Feature",
        "geometry" => {
          "type" => "Point",
          "coordinates" => [longitude, latitude]
        },
        "properties" => {
          "resource_type" => RESOURCE_TYPE_MAPPING[mappable_type.to_sym],
          "id" => mappable_id,
          "feature_color" => get_feature_color,
          "feature_icon_name" => get_feature_icon_name,
          "feature_icon_unicode" => get_feature_icon_unicode
        }
      }]
    }
  end

  def features_json_data(mark_masterportal_pin: true)
    extra_properties = {
      "resource_type" => RESOURCE_TYPE_MAPPING[mappable_type.to_sym],
      "id" => mappable_id,
      "feature_color" => get_feature_color,
      "feature_icon_name" => get_feature_icon_name,
      "feature_icon_unicode" => get_feature_icon_unicode,
      "feature_icon_url" => get_feature_icon_url
    }.reject { |_k, v| v.in?([nil, ""]) }

    extra_properties.merge!(masterportal_feature_properties) if mark_masterportal_pin

    enriched_geojson = to_geo_json

    enriched_geojson["features"].each do |feature|
      feature["properties"].merge!(extra_properties)
    end

    enriched_geojson
  end

  def masterportal_feature_properties
    return {} if !imported_from_masterportal?

    pin = mappable.masterportal_pin
    return {} if pin.blank?

    {
      "resource_type" => "masterportal_pin",
      "id" => pin.id,
      "feature_icon_url" => pin.feature_icon_url
    }
  end

  def get_district_id
    RegisteredAddress::District.joins(:map_location).find_each do |district|
      if district.map_location.intersects?(self)
        return district.id
      end
    end

    nil
  end

  def intersects?(other_map_location)
    factory = RGeo::Geos.factory

    geom1 =  RGeo::GeoJSON.decode(to_geo_json, json_parser: :json, geo_factory: factory).map(&:geometry)
    geom2 =  RGeo::GeoJSON.decode(other_map_location.to_geo_json, json_parser: :json, geo_factory: factory).map(&:geometry)

    geom1.any? { |g1| geom2.any? { |g2| g1.intersects?(g2) } }
  rescue RGeo::Error::InvalidGeometry
    false
  end

  private

    def set_default_values
      return unless new_record?
      return if mappable.is_a?(Budget::Investment) && mappable.budget.blank?

      if mappable.is_a?(ProjektPhase)
        self.latitude          ||= mappable.projekt.map_location.latitude
        self.longitude         ||= mappable.projekt.map_location.longitude
        self.zoom              ||= mappable.projekt.map_location.zoom
        self.altitude          ||= mappable.projekt.map_location.altitude
        self.features          ||= mappable.projekt.map_location.features
        self.rendering_library ||= mappable.projekt.map_location.rendering_library

      elsif mappable.is_a?(Projekt) && mappable.parent.present?
        self.latitude          ||= mappable.parent.map_location.latitude
        self.longitude         ||= mappable.parent.map_location.longitude
        self.zoom              ||= mappable.parent.map_location.zoom
        self.altitude          ||= mappable.parent.map_location.altitude
        self.features          ||= mappable.parent.map_location.features
        self.rendering_library ||= mappable.parent.map_location.rendering_library

      elsif mappable.is_a?(Projekt) || mappable.is_a?(RegisteredAddress::District)
        self.latitude          ||= MapLocation.default.latitude
        self.longitude         ||= MapLocation.default.longitude
        self.zoom              ||= MapLocation.default.zoom
        self.altitude          ||= MapLocation.default.altitude
        self.features          ||= MapLocation.default.features
        self.rendering_library ||= MapLocation.default.rendering_library

      elsif mappable.respond_to?(:projekt_phase) && mappable.projekt_phase.present?
        self.latitude          ||= mappable.projekt_phase.map_location.latitude
        self.longitude         ||= mappable.projekt_phase.map_location.longitude
        self.zoom              ||= mappable.projekt_phase.map_location.zoom
        self.altitude          ||= mappable.projekt_phase.map_location.altitude
        self.rendering_library = mappable.projekt_phase.map_location.rendering_library

      else
        self.latitude          ||= default ? Setting["map.latitude"] : self.class.default.latitude
        self.longitude         ||= default ? Setting["map.longitude"] : self.class.default.longitude
        self.zoom              ||= default ? Setting["map.zoom"] : self.class.default.zoom
        self.altitude          ||= default ? 80 : self.class.default.altitude
        self.rendering_library ||= default ? "leaflet" : self.class.default.rendering_library
      end
    end

    def get_approximated_address
      return unless geocoder_data.present?

      locality = [
        geocoder_data["address"]["neighbourhood"],
        geocoder_data["address"]["suburb"],
        geocoder_data["address"]["village"],
        geocoder_data["address"]["town"],
        geocoder_data["address"]["city"]
      ].compact.join(", ")

      street_address = [
        geocoder_data["address"]["road"],
        geocoder_data["address"]["house_number"]
      ].compact.join(" ")

      "#{street_address}, #{geocoder_data["address"]["postcode"]} #{locality}"
    end

    def get_feature_color(category: nil, sentiment: nil)
      sentiment ||= mappable.sentiment if mappable.respond_to?(:sentiment)
      category ||= mappable.category if mappable.respond_to?(:category)

      if sentiment.present? && (mappable.is_a?(Budget::Investment) || mappable.is_a?(Proposal))
        sentiment.color
      elsif category.present? && (mappable.is_a?(DeficiencyReport) || mappable.is_a?(Idea))
        category.color
      end
    end

    def get_feature_icon_name(category: nil, projekt_labels: nil)
      @icon_name ||= begin
        projekt_labels ||= mappable.projekt_labels if mappable.respond_to?(:projekt_labels)
        category ||= mappable.category if mappable.respond_to?(:category)

        if (mappable.is_a?(Proposal) || mappable.is_a?(Budget::Investment)) && projekt_labels&.any?
          projekt_labels.size == 1 ? projekt_labels.first.icon : "tags"
        elsif (mappable.is_a?(DeficiencyReport) || mappable.is_a?(Idea)) && category.present?
          category.icon
        end
      end
    end

    def get_feature_icon_unicode(category: nil, projekt_labels: nil)
      icon_name = get_feature_icon_name(category: category, projekt_labels: projekt_labels)
      return unless icon_name.present?

      self.class.awesome_icon_unicode_cache[icon_name]
    end

    def get_feature_icon_url
      return if !(mappable.is_a?(Proposal) || mappable.is_a?(Budget::Investment))

      labels = mappable.projekt_labels
      return if labels.blank? || labels.size != 1

      labels.first.image_icon_url
    end

    def update_geocoder_data
      return if skip_masterportal_geocoding
      return if imported_from_masterportal?
      return if to_geo_json["features"].first.blank?

      lat = to_geo_json["features"].first["geometry"]["coordinates"][1]
      lon = to_geo_json["features"].first["geometry"]["coordinates"][0]

      update_column(:geocoder_data, Geocoder.search([lat, lon]).first&.data)
      update_column(:approximated_address, get_approximated_address)
    rescue StandardError => e
      Sentry.capture_exception(e)
      update_column(:geocoder_data, {}) unless geocoder_data.present?
    end

    def imported_from_masterportal?
      mappable.respond_to?(:masterportal_pin_id) && mappable.masterportal_pin_id.present?
    end

    def audit_changes?
      return false unless mappable.is_a?(DeficiencyReport)

      mappable.previous_changes.any? { |k, _v| k.in?(%w[features latitude longitude]) }
    end

    def parse_features_string
      if features.is_a?(String)
        begin
          self.features = JSON.parse(features)
        rescue JSON::ParserError => e
          Sentry.capture_exception(e)
          self.features = { "type" => "FeatureCollection", "features" => [] }
        end
      end
    end

    def update_district
      return if skip_masterportal_geocoding
      return if imported_from_masterportal?
      return if mappable.is_a?(RegisteredAddress::District)

      district_id = get_district_id
      return if registered_address_district_id == district_id

      update_column(:registered_address_district_id, district_id)
    end
end
