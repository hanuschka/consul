require_dependency Rails.root.join("app", "models", "user").to_s

class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :confirmable, :recoverable, :rememberable,
         :timeoutable,
         :validatable, :omniauthable, :password_expirable, :secure_validatable,
         authentication_keys: [:login]

  before_create :set_default_privacy_settings_to_false, if: :gdpr_conformity?
  around_update :reset_verification_status

  has_many :projekts, -> { with_hidden }, foreign_key: :author_id, inverse_of: :author
  has_many :projekt_questions, foreign_key: :author_id #, inverse_of: :author
  has_many :deficiency_reports, -> { with_hidden }, foreign_key: :author_id, inverse_of: :author
  has_one :deficiency_report_officer, class_name: "DeficiencyReport::Officer"
  has_one :projekt_manager
  belongs_to :bam_street
  scope :outside_bam, -> { where(location: 'not_citizen').where.not(bam_letter_verification_code: nil).order(id: :desc) }
  scope :projekt_managers, -> { joins(:projekt_manager) }

  validates :first_name, presence: true, on: :create, if: :first_name_required?
  validates :last_name, presence: true, on: :create, if: :last_name_required?
  validates :street_name, presence: true, on: :create, if: :street_name_required?
  validates :street_number, presence: true, on: :create, if: :street_number_required?
  validates :plz, presence: true, on: :create, if: :plz_required?
  validates :city_name, presence: true, on: :create, if: :city_name_required?
  validates :date_of_birth, presence: true, on: :create, if: :date_of_birth_required?
  validates :gender, presence: true, on: :create, if: :gender_required?
  validates :document_last_digits, presence: true, on: :create, if: :document_last_digits_required?

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
    location == "citizen"
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

  def take_votes_if_erased_exists(bam_unique_stamp)
    erased_user = User.erased.find_by(bam_unique_stamp: bam_unique_stamp)

    if erased_user.present?
      take_votes_from(erased_user)
      erased_user.update!(bam_unique_stamp: nil, document_number: nil, document_type: nil)
    end
  end

  def reset_verification_status
    if (first_name_changed? || last_name_changed? || date_of_birth_changed? || plz_changed?) &&
        verified_at.present? &&
        bam_unique_stamp.present?
      update_columns(verified_at: nil, bam_unique_stamp: nil)
    end

    yield
  end

  def projekt_manager?
    projekt_manager.present?
  end

  def first_name_required?
    false
    # !organization? && !erased? && Setting["extra_fields.registration.first_name"]
  end

  def last_name_required?
    false
    # !organization? && !erased? && Setting["extra_fields.registration.last_name"]
  end

  def street_name_required?
    false
    # !organization? && !erased? && Setting["extra_fields.registration.street_name"]
  end

  def street_number_required?
    false
    # !organization? && !erased? && Setting["extra_fields.registration.street_number"]
  end

  def plz_required?
    false
    # !organization? && !erased? && Setting["extra_fields.registration.plz"]
  end

  def city_name_required?
    false
    # !organization? && !erased? && Setting["extra_fields.registration.city_name"]
  end

  def date_of_birth_required?
    false
    # !organization? && !erased? && Setting["extra_fields.registration.date_of_birth"]
  end

  def gender_required?
    false
    # !organization? && !erased? && Setting["extra_fields.registration.gender"]
  end

  def document_last_digits_required?
    false
    # !organization? && !erased? && Setting["extra_fields.registration.document_last_digits"]
  end
end
