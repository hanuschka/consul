class PendingRoleAssignment < ApplicationRecord
  ROLE_TYPES = %w[
    Administrator Moderator Manager Valuator
    DeficiencyReportManager IdeaManager ProjektManager OfficingManager
    LandingPageManager
  ].freeze

  has_secure_token :invitation_token

  belongs_to :created_by, class_name: "User", optional: true

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role_type, presence: true, inclusion: { in: ROLE_TYPES }
  validates :email, uniqueness: { scope: :role_type }

  before_validation :normalize_email

  scope :for_email, ->(email) { where(email: email&.strip&.downcase) }
  scope :for_role_type, ->(type) { where(role_type: type) }

  def self.find_by_invitation_token(token)
    return nil if token.blank?

    find_by(invitation_token: token)
  end

  def fulfill!(user)
    raise ArgumentError, "Invalid role_type: #{role_type}" unless ROLE_TYPES.include?(role_type)

    role_class = role_type.constantize
    return if role_class.exists?(user_id: user.id)

    role_class.create!(user_id: user.id)
    destroy!
  end

  private

    def normalize_email
      self.email = email&.strip&.downcase&.gsub(/[[:space:]\u200B\uFEFF]/, "")
    end
end
