class ApiClient < ApplicationRecord
  enum registration_status: [:registration_in_progress, :registered]
  has_secure_token :consul_auth_token

  before_create do
    self.registration_status = :registration_in_progress
  end

  def self.dt
    registered.find_by(name: "DT")
  end

  def self.active_dt?
    client = dt

    client.present? && client.service_auth_token.present?
  end

  def mark_as_registered!(service_auth_token)
    update!(
      registration_status: :registered,
      service_auth_token: service_auth_token
    )
  end
end
