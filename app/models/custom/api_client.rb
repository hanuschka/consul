class ApiClient < ApplicationRecord
  enum :access_level, { public_data: "public_data", admin: "admin" }

  has_one :user, foreign_key: :api_client_id

  validates :name, uniqueness: true, presence: true
  validates :access_level, presence: true
  validates :service_user_email, presence: true, uniqueness: true, if: :dedicated_user_mode?
  validate :instance_configuration_access_requires_admin

  before_create :generate_access_token

  def can_read_public_data?
    public_data? || admin?
  end

  def can_configure_instance?
    admin? && instance_configuration_access?
  end

  def regenerate_access_token
    generate_access_token
    save!
  end

  def dedicated_user_mode?
    !use_system_user?
  end

  def content_author
    if dedicated_user_mode? && user.present?
      user
    else
      User.system
    end
  end

  private

  def instance_configuration_access_requires_admin
    return if !instance_configuration_access? || admin?

    errors.add(:instance_configuration_access, :requires_admin_access_level)
  end

  def generate_access_token
    self.access_token = "sk_#{SecureRandom.hex(41)}"
  end
end
