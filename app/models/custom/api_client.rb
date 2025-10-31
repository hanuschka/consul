class ApiClient < ApplicationRecord
  enum registration_status: [:registration_in_progress, :registered]
  enum access_level: { public_data: "public_data", admin: "admin" }
  has_secure_token :auth_token

  has_many :created_ideas, class_name: 'Idea', foreign_key: 'api_client_created_id', dependent: :nullify
  has_many :created_proposals, class_name: 'Proposal', foreign_key: 'api_client_created_id', dependent: :nullify
  has_many :created_deficiency_reports, class_name: 'DeficiencyReport', foreign_key: 'api_client_created_id', dependent: :nullify
  has_many :created_budget_investments, class_name: 'Budget::Investment', foreign_key: 'api_client_created_id', dependent: :nullify
  has_many :created_projekt_point_of_interest_pins, class_name: 'ProjektPointOfInterestPin', foreign_key: 'api_client_created_id', dependent: :nullify

  has_many :last_updated_ideas, class_name: 'Idea', foreign_key: 'api_client_last_updated_id', dependent: :nullify
  has_many :last_updated_proposals, class_name: 'Proposal', foreign_key: 'api_client_last_updated_id', dependent: :nullify
  has_many :last_updated_deficiency_reports, class_name: 'DeficiencyReport', foreign_key: 'api_client_last_updated_id', dependent: :nullify
  has_many :last_updated_budget_investments, class_name: 'Budget::Investment', foreign_key: 'api_client_last_updated_id', dependent: :nullify
  has_many :last_updated_projekt_point_of_interest_pins, class_name: 'ProjektPointOfInterestPin', foreign_key: 'api_client_last_updated_id', dependent: :nullify

  validates :access_level, presence: true

  before_create do
    if registration_status.nil?
      self.registration_status = :registration_in_progress
    end
  end

  def self.dt
    registered.find_by(name: "DT")
  end

  def self.active_dt?
    client = dt

    client.present? && client.service_api_token.present?
  end

  def mark_as_registered!(service_api_token)
    update!(
      registration_status: :registered,
      service_api_token: service_api_token
    )
  end
end
