require_dependency Rails.root.join("app", "models", "user").to_s

class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :confirmable, :recoverable, :rememberable,
         :timeoutable,
         :trackable, :validatable, :omniauthable, :password_expirable, :secure_validatable,
         authentication_keys: [:login]

  before_create :set_default_privacy_settings_to_false, if: :gdpr_conformity?
  after_create :attempt_verification

  has_many :projekts, -> { with_hidden }, foreign_key: :author_id, inverse_of: :author
  has_many :projekt_questions, foreign_key: :author_id #, inverse_of: :author
  has_many :deficiency_reports, -> { with_hidden }, foreign_key: :author_id, inverse_of: :author
  has_one :deficiency_report_officer, class_name: "DeficiencyReport::Officer"
  has_one :projekt_manager

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

  def deficiency_report_votes(deficiency_reports)
    voted = votes.for_deficiency_reports(Array(deficiency_reports).map(&:id))
    voted.each_with_object({}) { |v, h| h[v.votable_id] = v.value }
  end

  def deficiency_report_officer?
    deficiency_report_officer.present?
  end

  def projekt_manager?
    projekt_manager.present?
  end

  private

      def attempt_verification
      return false unless stamp_unique?
      return false unless residency_valid?

      attributes_to_set = {
        geozone: geozone_with_plz,
        verified_at: Time.current
      }

      unless organization?
        attributes_to_set[:unique_stamp] = prepare_unique_stamp
      end

      update!(attributes_to_set)
    end


    def census_data
      RemoteCensusApi.new.call(first_name: first_name,
                               last_name: last_name,
                               street_name: street_name,
                               street_number: street_number,
                               plz: plz,
                               city_name: city_name,
                               date_of_birth: date_of_birth.strftime("%Y-%m-%d"),
                               gender: gender)
    end

    def residency_valid?
      census_data.valid?
    end

    def geozone_with_plz
      return nil unless plz.present?

      Geozone.where.not(postal_codes: nil).select do |geozone|
        geozone.postal_codes.split(",").any? do |postal_code|
          postal_code.strip == plz.to_s
        end
      end.first
    end

    def stamp_unique?
      User.find_by(unique_stamp: prepare_unique_stamp).blank?
    end

    def prepare_unique_stamp
      first_name.downcase + "_" +
        last_name.downcase + "_" +
        date_of_birth.to_date.strftime("%Y_%m_%d") + "_" +
        plz.to_s
    end

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

    def first_name_required?
      !organization? && !erased? && Setting["extra_fields.registration.first_name"]
    end

    def last_name_required?
      !organization? && !erased? && Setting["extra_fields.registration.last_name"]
    end

    def street_name_required?
      !organization? && !erased? && Setting["extra_fields.registration.street_name"]
    end

    def street_number_required?
      !organization? && !erased? && Setting["extra_fields.registration.street_number"]
    end

    def plz_required?
      !organization? && !erased? && Setting["extra_fields.registration.plz"]
    end

    def city_name_required?
      !organization? && !erased? && Setting["extra_fields.registration.city_name"]
    end

    def date_of_birth_required?
      !organization? && !erased? && Setting["extra_fields.registration.date_of_birth"]
    end

    def gender_required?
      !organization? && !erased? && Setting["extra_fields.registration.gender"]
    end

    def document_last_digits_required?
      !organization? && !erased? && Setting["extra_fields.registration.document_last_digits"]
    end
  end
