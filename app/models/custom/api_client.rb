class ApiClient < ApplicationRecord
  enum registration_status: [:registration_in_progress, :registered]
  enum access_level: { public_data: "public_data", admin: "admin" }
  has_secure_token :auth_token

  has_one :user

  validates :access_level, presence: true

  before_create do
    if registration_status.nil?
      self.registration_status = :registration_in_progress
    end
  end

  after_create :create_service_user

  def can_read_public_data?
    public_data? || admin?
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

  def create_service_user
    username = generate_service_username

    User.create!(
      username: username,
      email: "#{username.downcase.gsub(/\s+/, '_')}@api-service.local",
      password: SecureRandom.hex(32),
      confirmed_at: Time.current,
      api_client: self,
      terms_data_storage: "1",
      terms_data_protection: "1",
      terms_general: "1",
      skip_password_validation: true
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create service user for ApiClient #{id}: #{e.message}"
  end

  private

  def generate_service_username
    base_username = "#{name}_service".parameterize.underscore
    username = base_username
    counter = 1

    while User.exists?(username: username)
      username = "#{base_username}_#{counter}"
      counter += 1
    end

    username
  end
end
