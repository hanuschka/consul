require_dependency Rails.root.join("app", "models", "user").to_s

class User < ApplicationRecord

  devise :database_authenticatable, :registerable, :confirmable, :recoverable, :rememberable,
         :timeoutable,
         :trackable, :validatable, :omniauthable, :password_expirable, :secure_validatable,
         authentication_keys: [:login]

  before_create :set_default_privacy_settings_to_false, if: :gdpr_conformity?

  has_many :projekts, -> { with_hidden }, foreign_key: :author_id, inverse_of: :author

  validates :document_number, uniqueness: { scope: [:document_type, :erased_at] }, allow_nil: true

  scope :outside_bam, -> { where(location: 'not_citizen').where.not(bam_letter_verification_code: nil) }

  def gdpr_conformity?
    Setting["extended_feature.gdpr.gdpr_conformity"].present?
  end

  def set_default_privacy_settings_to_false
    self.public_activity = false
    self.public_interests = false
    self.email_on_comment = false
    self.email_on_comment_reply = false
    self.newsletter = false
    self.email_digest = false
    self.email_on_direct_message = false
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def citizen?
    location == 'citizen'
  end

  def username
    full_name
  end

  def username_required?
    false
  end
end
