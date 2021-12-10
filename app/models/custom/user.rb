require_dependency Rails.root.join("app", "models", "user").to_s

class User < ApplicationRecord

  devise :database_authenticatable, :registerable, :confirmable, :recoverable, :rememberable,
         :timeoutable,
         :validatable, :omniauthable, :password_expirable, :secure_validatable,
         authentication_keys: [:login]

  before_create :set_default_privacy_settings_to_false, if: :gdpr_conformity?

  has_many :projekts, -> { with_hidden }, foreign_key: :author_id, inverse_of: :author
  has_many :deficiency_reports, -> { with_hidden }, foreign_key: :author_id, inverse_of: :author
  has_one :deficiency_report_officer, class_name: "DeficiencyReport::Officer"

  validates :document_number, uniqueness: { scope: [:document_type, :erased_at] }, allow_nil: true

  scope :outside_bam, -> { where(location: 'not_citizen').where.not(bam_letter_verification_code: nil).order(id: :desc) }

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

  def deficiency_report_votes(deficiency_reports)
    voted = votes.for_deficiency_reports(Array(deficiency_reports).map(&:id))
    voted.each_with_object({}) { |v, h| h[v.votable_id] = v.value }
  end

  def deficiency_report_officer?
    deficiency_report_officer.present?
  end

  def take_votes_if_erased_document(first_name, last_name, date_of_birth, plz)
    birth_year = date_of_birth.year
    birth_month = date_of_birth.month
    birth_day = date_of_birth.day

    erased_users_with_matching_birthday = User.erased.
       where('extract(year  from date_of_birth) = ?', birth_year).
       where('extract(month  from date_of_birth) = ?', birth_month).
       where('extract(day  from date_of_birth) = ?', birth_day)

    erased_user = erased_users_with_matching_birthday.find_by(
                    first_name: first_name,
                    last_name: last_name,
                    plz: plz
    )

    if erased_user.present?
      take_votes_from(erased_user)
      erased_user.update!(document_number: nil, document_type: nil)
    end
  end
end
