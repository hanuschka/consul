class ApiClient < ApplicationRecord
  enum access_level: { public_data: "public_data", admin: "admin" }

  has_one :user, foreign_key: :api_client_id

  validates :name, uniqueness: true, presence: true
  validates :access_level, presence: true
  validates :service_user_email, presence: true, uniqueness: true

  before_create :generate_access_token
  after_create :create_service_user

  def can_read_public_data?
    public_data? || admin?
  end

  def regenerate_access_token
    generate_access_token
    save!
  end

  def create_service_user
    username = generate_service_username

    User.create!(
      username: username,
      email: service_user_email,
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

  def generate_access_token
    prefix = environment_prefix
    random_token = SecureRandom.urlsafe_base64(48).tr('-_', 'A0')
    self.access_token = "#{prefix}-#{random_token}".slice(0, 64)
  end

  private

  def environment_prefix
    case Rails.env
    when 'test'
      'te'
    when 'production'
      'pr'
    when 'staging'
      'st'
    when 'development'
      'de'
    else
      'xx'
    end
  end

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
