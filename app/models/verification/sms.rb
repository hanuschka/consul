class Verification::Sms
  include ActiveModel::Model

  attr_accessor :user, :phone, :confirmation_code

  validates :phone, presence: true
  validate :german_mobile_phone
  validate :uniqness_phone

  def german_mobile_phone
    return if phone.blank? || normalized_phone.present?

    errors.add(:base, I18n.t("verification.sms.errors.not_german_mobile"))
  end

  def uniqness_phone
    errors.add(:phone, :taken) if normalized_phone && User.where(confirmed_phone: normalized_phone).any?
  end

  def save
    return false unless valid?

    update_user_phone_information
    return false unless send_sms

    Lock.increase_tries(user)
  end

  def update_user_phone_information
    user.update(unconfirmed_phone: normalized_phone, sms_confirmation_code: generate_confirmation_code)
  end

  def send_sms
    text = I18n.t("verification.sms.message", code: user.sms_confirmation_code)
    result = Sms::Gateway.deliver(to: user.unconfirmed_phone, text: text)
    errors.add(:base, I18n.t("verification.sms.errors.delivery_failed")) unless result.success?
    result.success?
  end

  def verified?
    user.sms_confirmation_code == confirmation_code
  end

  private

    def normalized_phone
      Sms::PhoneNumber.normalize(phone)
    end

    def generate_confirmation_code
      rand.to_s[2..5]
    end
end
