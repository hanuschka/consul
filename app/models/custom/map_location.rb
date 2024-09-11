require_dependency Rails.root.join("app", "models", "map_location").to_s

class MapLocation < ApplicationRecord
  belongs_to :projekt, touch: true
  belongs_to :deficiency_report, touch: true
  belongs_to :projekt_phase, touch: true
  belongs_to :deficiency_report_area, class_name: "DeficiencyReport::Area",
    foreign_key: :deficiency_report_area_id, touch: true, inverse_of: :map_location

  before_save :ensure_shape_is_json
  after_save :update_geocoder_data
  # before_save :set_pin_styles

  # def set_pin_styles
  #   self.pin_color = get_pin_color
  #   self.fa_icon_class = get_fa_icon_class
  # end

	reverse_geocoded_by :latitude, :longitude

  audited associated_with: :deficiency_report,
    only: %i[shape latitude longitude],
    if: :audit_changes?

  def json_data
    {
      investment_id: investment_id,
      proposal_id: proposal_id,
      projekt_id: projekt_id,
      deficiency_report_id: deficiency_report_id,
      lat: latitude,
      long: longitude,
      alt: altitude,
      color: get_pin_color,
      fa_icon_class: get_fa_icon_class
    }
  end

  def shape_json_data
    return {} if shape == {} || shape == "{}"

    if shape.is_a?(String)
      # Sentry.capture_message("MapJSONBug. Shape: #{shape}")
      return {}
    end

    shape.merge({
      investment_id: investment_id,
      proposal_id: proposal_id,
      projekt_id: projekt_id,
      deficiency_report_id: deficiency_report_id,
      color: get_pin_color,
      fa_icon_class: get_fa_icon_class
    })
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

  private

  def get_pin_color
    if proposal.present? && proposal.projekt_phase.projekt.overview_page?
      "#009900"

    elsif proposal.present? && proposal.sentiment.present?
      proposal.sentiment.color

    elsif investment.present?
      investment.projekt&.color || "#004a83"

    elsif deficiency_report.present?
      deficiency_report.category.color

    elsif projekt.present?
      "red"

    else
      "#004a83"
    end
  end

  def get_fa_icon_class
    if proposal.present? && proposal.projekt_labels.any?
      proposal.projekt_labels.size == 1 ? proposal.projekt_labels.first.icon : "tags"

    elsif investment.present? && investment.projekt.present?
      investment.projekt.icon

    elsif deficiency_report.present?
      deficiency_report.category.icon

    elsif projekt.present?
      projekt.icon

    else
      "circle"
    end
  end

  def ensure_shape_is_json
    if shape == "{}" || shape == "\"{}\"" || shape == '"{}"' || shape == ""
      self.shape = {}
    elsif shape.is_a?(String)
      self.shape = JSON.parse(shape)
    else
      self.shape = {}
    end
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
    return false unless deficiency_report.present?

    deficiency_report.previous_changes.any? { |k, _v| k.in?(%w(shape latitude longitude)) }
  end
end
