class ApiClient < ApplicationRecord
  enum registration_status: [:registration_in_progress, :registered]
  has_secure_token :auth_token

  before_create do
    self.registration_status = :registration_in_progress
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
