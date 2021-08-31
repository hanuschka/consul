require_dependency Rails.root.join("app", "models", "officing", "residence").to_s

class Officing::Residence

  attr_accessor :first_name, :last_name

  validates :first_name, presence: true
  validates :last_name, presence: true
	validates :postal_code, presence: true
  validates :date_of_birth, presence: true

  def save
    return false unless valid?

    if user_exists?
      self.user = find_user_by_document
      user.update!(verified_at: Time.current)
    else
      user_params = {
        document_number:       document_number,
        document_type:         document_type,
        first_name:            first_name,
        last_name:             last_name,
        plz:                   postal_code,
        geozone:               geozone,
        date_of_birth:         date_of_birth.in_time_zone.to_datetime,
        residence_verified_at: Time.current,
        verified_at:           Time.current,
        erased_at:             Time.current,
        password:              random_password,
        terms_of_service:      "1",
        email:                 nil
      }
      self.user = User.create!(user_params)
    end
  end


  def geozone
    Geozone.find_by(external_code: postal_code)
  end

  def allowed_age
    return if errors[:year_of_birth].any?

    unless allowed_age?
      errors.add(:year_of_birth, I18n.t("verification.residence.new.error_not_allowed_age"))
    end
  end

  def response_date_of_birth
    date_of_birth
  end

  def local_residence
    return if errors.any?
		true
	end
end
