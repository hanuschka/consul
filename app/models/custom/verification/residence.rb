require_dependency Rails.root.join("app", "models", "verification", "residence").to_s

class Verification::Residence
  attr_accessor :first_name, :last_name, :gender, :date_of_birth,
                :city_name, :plz, :street_name, :street_number, :street_number_extension,
                :document_type, :document_last_digits,
                :registered_address_id,
                :form_registered_address_city_id,
                :form_registered_address_street_id,
                :form_registered_address_id

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :gender, presence: true
  validates :date_of_birth, presence: true

  validates :registered_address_id, presence: true, if: :validate_registered_address?

  validates :city_name, presence: true, if: :validate_regular_address_fields?
  validates :plz, presence: true, if: :validate_regular_address_fields?
  validates :street_name, presence: true, if: :validate_regular_address_fields?
  validates :street_number, presence: true, if: :validate_regular_address_fields?

  validates :document_type, presence: true, if: :document_required?
  validates :document_last_digits, presence: true, if: :document_required?

  validates :terms_data_storage, acceptance: { allow_nil: false } #custom
  validates :terms_data_protection, acceptance: { allow_nil: false } #custom
  validates :terms_general, acceptance: { allow_nil: false } #custom

  def save
    return false unless valid?

    if form_registered_address_id.present? && form_registered_address_id != "0"
      registered_address = RegisteredAddress.find(form_registered_address_id)

      registered_address_id = registered_address.id

      self.city_name = registered_address.registered_address_city.name
      self.plz = registered_address.registered_address_street.plz
      self.street_name = registered_address.registered_address_street.name
      self.street_number = registered_address.street_number
      self.street_number_extension = registered_address.street_number_extension
    end

    user.assign_attributes(
      first_name:              first_name,
      last_name:               last_name,
      gender:                  gender,
      date_of_birth:           date_of_birth,
      city_name:               city_name,
      plz:                     plz,
      street_name:             street_name,
      street_number:           street_number,
      street_number_extension: street_number_extension,
      document_type:           document_type,
      document_last_digits:    document_last_digits,
      registered_address_id:   registered_address_id
    )

    if Setting["feature.melderegister"].present?
      user.save!
      user.verify!
    else
      user.save!
    end
  end

  def document_required?
    Setting["extra_fields.verification.check_documents"].present?
  end

  def validate_registered_address?
    return false unless RegisteredAddress.present?

    acceptable_values = ["0", nil]

    [form_registered_address_city_id,
      form_registered_address_street_id,
      form_registered_address_id].all? { |v| acceptable_values.exclude?(v) }
  end

  def validate_regular_address_fields?
    return true if RegisteredAddress.none?

    form_registered_address_city_id == "0" ||
      form_registered_address_street_id == "0" ||
      form_registered_address_id == "0"
  end

  private

    def census_data
      if form_registered_address_id.present? && form_registered_address_id != "0"
        registered_address = RegisteredAddress.find(form_registered_address_id)
        street_name = registered_address.registered_address_street.name
        street_number = registered_address.street_number
        plz = registered_address.registered_address_street.plz
        city_name = registered_address.registered_address_city.name
      else
        street_name = self.street_name
        street_number = self.street_number
        plz = self.plz
        city_name = self.city_name
      end
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
end
