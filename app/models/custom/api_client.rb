class ApiClient < ApplicationRecord
  enum access_level: { public_data: "public_data", admin: "admin" }

  has_one :user, foreign_key: :api_client_id

  validates :name, uniqueness: true, presence: true
  validates :access_level, presence: true
  validates :service_user_email, presence: true, uniqueness: true, if: :dedicated_user_mode?

  before_create :generate_access_token

  def can_read_public_data?
    public_data? || admin?
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

  def generate_access_token
    self.access_token = "sk_#{SecureRandom.hex(41)}"
  end
end
