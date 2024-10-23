class ApiClient < ApplicationRecord
  enum registration_status: [:registration_in_progress, :registered]
  has_secure_token :auth_token

  before_create do
    self.registration_status = :registration_in_progress
  end

  def self.active_dt?
    registered.where(name: "DT").any?
  end
end
