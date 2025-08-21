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

  enum rendering_library: { leaflet: 0, mapbox: 1, virtualcity: 2 }

  belongs_to :mappable, polymorphic: true, touch: true
  has_one_attached :screenshot

  validates :longitude, :latitude, :zoom, presence: true, numericality: true

  after_initialize :set_default_values
  before_save :parse_features_string
  after_save :update_geocoder_data

  reverse_geocoded_by :latitude, :longitude

  audited associated_with: :deficiency_report,
    only: %i[features latitude longitude],
    if: :audit_changes?

  def available?
    latitude.present? && longitude.present? && zoom.present?
  end

  def json_data
    debugger
    {
      resource_type: RESOURCE_TYPE_MAPPING[mappable_type.to_sym],
      id: mappable_id,
      lat: latitude,
      long: longitude,
      alt: altitude,
      color: get_feature_color,
      fa_icon_class: get_fa_icon_class
    }
  end

  def features_json_data
    if features.is_a?(String)
      Sentry.capture_message("MapLocation #{id} features is a String")
    end

    return {} if features == {} || features.is_a?(String)

    extra_properties = {
      "resource_type" => RESOURCE_TYPE_MAPPING[mappable_type.to_sym],
      "id" => mappable_id,
      "color" => get_feature_color,
      "fa_icon_class" => get_fa_icon_class
    }

    if features["type"] == "FeatureCollection"
      features["features"].each do |feature|
        feature["properties"].merge!(extra_properties)
      end
    elsif features["type"] == "Feature"
      features["properties"].merge!(extra_properties)
    else
      Sentry.capture_message("MapLocation #{id} features is not a FeatureCollection or Feature")
      return {}
    end

    features
  end

  def get_district
    return unless latitude.present? && longitude.present?

    geo_data = Geocoder.search([latitude, longitude]).first&.data

    matching_address_query = {
      street_number: geo_data["address"]["house_number"]&.match(/\A\d+/).to_s,
      street_number_extension: geo_data["address"]["house_number"]&.match(/[a-zA-Z]+\z/).to_s.downcase.presence,
      registered_address_street: {
        name: geo_data["address"]["road"],
        plz: geo_data["address"]["postcode"]
      },
      registered_address_city: {
        name: geo_data["address"]["city"] || geo_data["address"]["town"]
      }
    }.reject { |_k, v| v.in?(["", nil]) }

    RegisteredAddress.joins(:registered_address_street, :registered_address_city).find_by(matching_address_query)&.district
  end

  private

    def set_default_values
      return unless new_record?

      if parent = mappable.respond_to?(:projekt_phase) ? mappable.projekt_phase : mappable.try(:projekt)
        self.latitude  ||= parent.map_location.latitude
        self.longitude ||= parent.map_location.longitude
        self.zoom      ||= parent.map_location.zoom
        self.altitude  ||= parent.map_location.altitude
      else
        self.latitude  ||= Setting["map.latitude"]
        self.longitude ||= Setting["map.longitude"]
        self.zoom      ||= Setting["map.zoom"]
        self.altitude  ||= 80
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

    def get_feature_color
      if mappable.is_a?(Proposal) && mappable.sentiment.present?
        mappable.sentiment.color
      elsif mappable.is_a?(DeficiencyReport)
        mappable.category.color
      end
    end

    def get_fa_icon_class
      if mappable.is_a?(Proposal) && mappable.projekt_labels.any?
        mappable.projekt_labels.size == 1 ? mappable.projekt_labels.first.icon : "tags"
      elsif mappable.is_a?(DeficiencyReport)
        mappable.category.icon
      else
        "circle"
      end
    end

    def update_geocoder_data
      return unless latitude.present? && longitude.present?

      update_column(:geocoder_data, Geocoder.search([latitude, longitude]).first&.data)
      update_column(:approximated_address, get_approximated_address)
    rescue StandardError => e
      Sentry.capture_exception(e)
      update_column(:geocoder_data, {}) unless geocoder_data.present?
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
          self.features = {}
          self.features_bu = features
        end
      end
    end
end
