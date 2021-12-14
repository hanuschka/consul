require_dependency Rails.root.join("app", "models", "user").to_s

class User < ApplicationRecord

  devise :database_authenticatable, :registerable, :confirmable, :recoverable, :rememberable,
         :timeoutable,
         :validatable, :omniauthable, :password_expirable, :secure_validatable,
         authentication_keys: [:login]

  before_create :set_default_privacy_settings_to_false, if: :gdpr_conformity?
  around_save :reset_verification_status

  has_many :projekts, -> { with_hidden }, foreign_key: :author_id, inverse_of: :author
  has_many :deficiency_reports, -> { with_hidden }, foreign_key: :author_id, inverse_of: :author
  has_one :deficiency_report_officer, class_name: "DeficiencyReport::Officer"

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

  def take_votes_if_erased_document(f_name, l_name, birth_date, postcode)
    birth_year = birth_date.year
    birth_month = birth_date.month
    birth_day = birth_date.day

    erased_users_with_matching_birthday = User.erased.
      where('extract(year  from date_of_birth) = ?', birth_year).
      where('extract(month  from date_of_birth) = ?', birth_month).
      where('extract(day  from date_of_birth) = ?', birth_day)

    erased_user = erased_users_with_matching_birthday.find_by(
                    first_name: f_name,
                    last_name: l_name,
                    plz: postcode
    )

    if erased_user.present?
      take_votes_from(erased_user)
      erased_user.update!(document_number: nil, document_type: nil)
    end
  end

  def record_not_unique?(f_name, l_name, birth_year, birth_month, birth_day, postcode)
    user = User.active.
      where('extract(year  from date_of_birth) = ?', birth_year).
      where('extract(month  from date_of_birth) = ?', birth_month).
      where('extract(day  from date_of_birth) = ?', birth_day).
      find_by(first_name: f_name, last_name: l_name, plz: postcode)

    user.present?
  end

  def reset_verification_status
    if (first_name_changed? || last_name_changed? || date_of_birth_changed? || plz_changed?) && persisted?
      update_column(:verified_at, nil)
    end

    yield
  end
end
