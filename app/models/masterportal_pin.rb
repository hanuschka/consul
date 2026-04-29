class MasterportalPin < ApplicationRecord
  belongs_to :projekt_phase
  has_one :proposal, foreign_key: :masterportal_pin_id, dependent: :nullify
  has_one :budget_investment, foreign_key: :masterportal_pin_id,
          class_name: "Budget::Investment", dependent: :nullify
  has_one :projekt_point_of_interest_pin, foreign_key: :masterportal_pin_id,
          dependent: :nullify
  has_one_attached :icon_image

  validates :external_id, :endpoint_url, :collection_id, :latitude, :longitude, presence: true

  scope :standalone, lambda {
    left_outer_joins(:proposal, :budget_investment, :projekt_point_of_interest_pin)
      .where(
        proposals: { id: nil },
        budget_investments: { id: nil },
        projekt_point_of_interest_pins: { id: nil }
      )
  }

  def self.standalone_features_for_phase(projekt_phase)
    return [] if projekt_phase.blank?

    where(projekt_phase_id: projekt_phase.id)
      .standalone
      .with_attached_icon_image
      .map(&:to_map_feature)
  end

  def associated_record
    proposal || budget_investment || projekt_point_of_interest_pin
  end

  def to_map_feature
    {
      "type" => "Feature",
      "geometry" => {
        "type" => "Point",
        "coordinates" => [longitude.to_f, latitude.to_f]
      },
      "properties" => {
        "resource_type" => "masterportal_pin",
        "id" => id,
        "feature_icon_url" => feature_icon_url
      }
    }
  end

  def popup_data
    Masterportal::PopupDataBuilder.call(pin: self)
  end

  def feature_icon_url
    return nil if !icon_image.attached?

    Rails.application.routes.url_helpers.rails_blob_url(
      icon_image, host: default_host, only_path: false
    )
  end

  def associated_resource_url
    record = associated_record
    return nil if record.nil?

    url_builder = Rails.application.routes.url_helpers

    case record
    when Proposal
      url_builder.proposal_url(record, host: default_host)
    when Budget::Investment
      url_builder.budget_investment_url(record.budget, record, host: default_host)
    when ProjektPointOfInterestPin
      nil
    end
  end

  private

    def default_host
      Rails.application.routes.default_url_options[:host] ||
        Setting["url"].presence ||
        "localhost"
    end
end
