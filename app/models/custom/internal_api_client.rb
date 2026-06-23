class InternalApiClient < ApplicationRecord
  enum registration_status: [:registration_in_progress, :registered]
  has_secure_token :auth_token, length: 85

  validates :name, presence: true
  validates :name, uniqueness: true, on: :create
  validates :domain, uniqueness: true, on: :create, if: :domain_present?

  before_create do
    if registration_status.nil?
      self.registration_status = :registration_in_progress
    end
  end

  def self.dt
    registered.find_by(name: "DT")
  end

  def self.find_or_initialize_dt
    find_or_initialize_by(name: "DT")
  end

  def self.dt_connected?
    client = dt

    client.present? && client.service_api_token.present?
  end

  def self.active_dt?
    dt_connected?
  end

  def public_data?
    false
  end

  def admin?
    true
  end

  def can_read_public_data?
    true
  end

  def content_author
    User.system
  end

  def mark_as_registered!(service_api_token)
    update!(
      registration_status: :registered,
      service_api_token: service_api_token
    )
  end

  private

  def domain_present?
    domain.present?
  end
end
