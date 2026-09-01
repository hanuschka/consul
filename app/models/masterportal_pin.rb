class MasterportalPin < ApplicationRecord
  belongs_to :projekt_phase
  belongs_to :masterportal_collection, optional: true
  has_one :proposal, foreign_key: :masterportal_pin_id, dependent: :nullify
  has_one :budget_investment, foreign_key: :masterportal_pin_id,
          class_name: "Budget::Investment", dependent: :nullify
  has_one :projekt_point_of_interest_pin, foreign_key: :masterportal_pin_id,
          dependent: :nullify
  validates :external_id, :endpoint_url, :collection_id, :latitude, :longitude, presence: true

  scope :standalone, lambda {
    left_outer_joins(:proposal, :budget_investment, :projekt_point_of_interest_pin)
      .where(
        proposals: { id: nil },
        budget_investments: { id: nil },
        projekt_point_of_interest_pins: { id: nil }
      )
  }

  scope :with_associated_record, lambda {
    left_outer_joins(:proposal, :budget_investment, :projekt_point_of_interest_pin)
      .where(
        "proposals.id IS NOT NULL OR budget_investments.id IS NOT NULL " \
        "OR projekt_point_of_interest_pins.id IS NOT NULL"
      )
  }

  scope :text_search, lambda { |query|
    cleaned = query.to_s.strip
    next all if cleaned.blank?

    pattern = "%#{sanitize_sql_like(cleaned)}%"
    where(
      "title ILIKE :pattern OR description ILIKE :pattern OR " \
      "external_id ILIKE :pattern OR collection_id ILIKE :pattern OR " \
      "(properties::text ILIKE :pattern AND EXISTS (" \
        "SELECT 1 FROM jsonb_path_query(properties, 'strict $.**') AS v " \
        "WHERE jsonb_typeof(v) IN ('string', 'number', 'boolean') " \
        "AND (v #>> '{}') ILIKE :pattern" \
      "))",
      pattern: pattern
    )
  }

  def self.standalone_features_for_phase(projekt_phase)
    return [] if projekt_phase.blank?

    where(projekt_phase_id: projekt_phase.id)
      .standalone
      .includes(:masterportal_collection)
      .map(&:to_map_feature)
  end

  def associated_record
    proposal || budget_investment || projekt_point_of_interest_pin
  end

  def to_map_feature(include_search_text: true, include_icon_url: true)
    feature_geometry = map_geometry
    icon_url = feature_icon_url

    properties = {
      "resource_type" => "masterportal_pin",
      "id" => id
    }
    properties["feature_icon_url"] = icon_url if include_icon_url
    properties["search_text"] = searchable_text if include_search_text

    color = fill_color

    if color.present? && colorable_feature?(feature_geometry, icon_url)
      properties["feature_color"] = color
    end

    {
      "type" => "Feature",
      "geometry" => feature_geometry,
      "properties" => properties
    }
  end

  def searchable_text
    parts = [title, description, external_id, collection_id]
    parts += flatten_property_values(properties)

    parts.compact_blank.map { |part| part.to_s.strip }.compact_blank.join(" ").downcase
  end

  def popup_data
    Masterportal::PopupDataBuilder.call(pin: self)
  end

  def self.icon_url_from_properties(pin_properties)
    pin_properties.to_h["IMAGE_URL"].to_s.strip.presence
  end

  def feature_icon_url
    self.class.icon_url_from_properties(properties)
  end

  def associated_resource_url
    record = associated_record
    return nil if record.nil?

    url_builder = Rails.application.routes.url_helpers

    case record
    when Proposal
      url_builder.proposal_url(record, only_path: true)
    when Budget::Investment
      url_builder.budget_investment_url(record.budget, record, only_path: true)
    when ProjektPointOfInterestPin
      nil
    end
  end

  private

    def map_geometry
      return geometry if geometry.is_a?(Hash) && geometry["type"].present?

      {
        "type" => "Point",
        "coordinates" => [longitude.to_f, latitude.to_f]
      }
    end

    def colorable_feature?(feature_geometry, icon_url)
      return true if feature_geometry["type"] != "Point"

      icon_url.blank?
    end

    def fill_color
      masterportal_collection&.feature_color
    end

    def flatten_property_values(value)
      case value
      when Hash
        value.flat_map { |key, inner| [key.to_s] + flatten_property_values(inner) }
      when Array
        value.flat_map { |inner| flatten_property_values(inner) }
      else
        [value.to_s]
      end
    end
end
