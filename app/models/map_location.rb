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

  enum rendering_library: { leaflet: 0, mapbox: 1, vc_maps: 2 }

  belongs_to :mappable, polymorphic: true, touch: true
  has_one_attached :screenshot

  validates :longitude, :latitude, :zoom, presence: true, numericality: true

  before_save :ensure_shape_is_json
  after_save :update_geocoder_data

  reverse_geocoded_by :latitude, :longitude

  audited associated_with: :deficiency_report,
    only: %i[shape latitude longitude],
    if: :audit_changes?

  def available?
    latitude.present? && longitude.present? && zoom.present?
  end

  def json_data
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

  def shape_json_data
    return {} if shape == {} || shape.is_a?(String)

    shape_additional_data =
      {
        resource_type: RESOURCE_TYPE_MAPPING[mappable_type.to_sym],
        id: mappable_id,
        color: get_feature_color,
        fa_icon_class: get_fa_icon_class
      }

    if shape.is_a?(Array)
      shape.map do |shape_item|
        shape_item.merge(shape_additional_data)
      end
    else
      shape.merge(shape_additional_data)
    end
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

    def ensure_shape_is_json
      self.shape = JSON.parse(shape) if shape.is_a?(String)
    rescue JSON::ParserError
      self.shape = {}
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

      mappable.previous_changes.any? { |k, _v| k.in?(%w[shape latitude longitude]) }
    end
end
