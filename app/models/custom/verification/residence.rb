require_dependency Rails.root.join("app", "models", "verification", "residence").to_s

class Verification::Residence
  attr_accessor :first_name, :last_name, :street_name, :street_number,
                :plz, :city_name, :document_last_digits, :date_of_birth, :gender

  validates :first_name, presence: true, if: :first_name_required?
  validates :last_name, presence: true, if: :last_name_required?
  validates :street_name, presence: true, if: :street_name_required?
  validates :street_number, presence: true, if: :street_number_required?
  validates :plz, presence: true, if: :plz_required?
  validates :city_name, presence: true, if: :city_name_required?
  validates :gender, presence: true, if: :gender_required?
  validates :date_of_birth, presence: true, if: :date_of_birth_required?
  validate  :allowed_age, if: :date_of_birth_required?
  # validates :document_last_digits, presence: true, if: :document_last_digits_required?

  # validates :document_number, presence: true, unless: :manual_verification?
  # validates :document_type, presence: true, unless: :manual_verification?
  # validates :postal_code, presence: true, unless: :manual_verification?
  # validate :local_postal_code, unless: :manual_verification?
  # validate :local_residence, unless: :manual_verification?
  validate :user_credentials_uniqueness

  def save
    return false unless valid?

    user.update!(first_name:            first_name,
                 last_name:             last_name,
                 street_name:           street_name,
                 street_number:         street_number,
                 plz:                   plz,
                 city_name:             city_name,
                 geozone:               geozone_with_plz,
                 date_of_birth:         date_of_birth.in_time_zone.to_datetime,
                 gender:                gender,
                 unique_stamp:          prepare_unique_stamp,
                 verified_at:           Time.current)
  end

  def save_manual_verification
    return false unless valid?

    user.update!(first_name:            first_name,            #custom
                 last_name:             last_name,             #custom
                 street_name:           street_name,           #custom
                 street_number:         street_number,         #custom
                 plz:                   plz,                   #custom
                 city_name:             city_name,             #custom
                 document_last_digits:  document_last_digits,  #custom
                 geozone:               geozone_with_plz,      #custom
                 gender:                gender)
  end

  private

    def census_data
      @census_data ||= RemoteCensusApi.new.call(first_name: first_name,
                                                last_name: last_name,
                                                street_name: street_name,
                                                street_number: street_number,
                                                plz: plz,
                                                city_name: city_name,
                                                date_of_birth: date_of_birth,
                                                gender: gender)
    end

    def residency_valid?
      census_data.valid?
    end

    def geozone_with_plz
      return nil unless plz.present?

      Geozone.where.not(postal_codes: nil).select do |geozone|
        geozone.postal_codes.split(",").any? do |postal_code|
          postal_code.strip == plz
        end
      end.first
    end

    def prepare_unique_stamp
      return nil if first_name.nil? || last_name.nil? || date_of_birth.nil? || plz.nil?

      first_name.downcase + "_" +
        last_name.downcase + "_" +
        date_of_birth.strftime("%Y_%m_%d") + "_" +
        plz
    end

    def user_credentials_uniqueness
      if User.find_by(unique_stamp: prepare_unique_stamp)
        errors.add(:local_residence, false)
      end
    end

    def document_number_uniqueness
      true

      # if User.active.where.not(id: user.id).where(document_number: document_number).any? &&
      #     !document_number.blank?
      #   errors.add(:document_number, I18n.t("errors.messages.taken"))
      # end
    end

    def manual_verification?
      Setting["extended_feature.verification.manual_verifications"].present?
    end

    def first_name_required?
      true

      # manual_verification? &&
        # Setting["extra_fields.verification.first_name"].present?
    end

    def last_name_required?
      true

      # manual_verification? &&
      #   Setting["extra_fields.verification.last_name"].present?
    end

    def street_name_required?
      true

      # manual_verification? &&
      #   Setting["extra_fields.verification.street_name"].present?
    end

    def street_number_required?
      true

      # manual_verification? &&
      #   Setting["extra_fields.verification.street_number"].present?
    end

    def plz_required?
      true

      # manual_verification? &&
      #   Setting["extra_fields.verification.plz"].present?
    end

    def city_name_required?
      true

      # manual_verification? &&
      #   Setting["extra_fields.verification.city_name"].present?
    end

    def date_of_birth_required?
      true

      # manual_verification? &&
      #   Setting["extra_fields.verification.date_of_birth"].present?
    end

    def gender_required?
      true

      # manual_verification? &&
      #   Setting["extra_fields.verification.gender"].present?
    end

    def document_last_digits_required?
      manual_verification? &&
        Setting["extra_fields.verification.document_last_digits"].present?
    end
end
