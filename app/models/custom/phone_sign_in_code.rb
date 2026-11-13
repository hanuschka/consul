class PhoneSignInCode < ApplicationRecord
  VALIDITY = 10.minutes
  MAX_ATTEMPTS = 5
  RESEND_COOLDOWN = 60.seconds
  MAX_PER_PHONE_PER_HOUR = 5
  MAX_PER_IP_PER_HOUR = 20
  RETENTION = 1.day

  scope :for_phone, ->(phone) { where(phone_digest: digest("phone", phone)) }

  def self.issue(phone:, ip:)
    where("created_at < ?", RETENTION.ago).delete_all
    return :rate_limited if rate_limited?(phone, ip)

    code = format("%06d", SecureRandom.random_number(1_000_000))
    record = create!(
      phone_digest: digest("phone", phone),
      ip_digest: ip.present? ? digest("ip", ip) : nil,
      code_digest: digest("code", phone, code),
      expires_at: VALIDITY.from_now
    )

    text = I18n.t("sms_sign_in.message", platform: Setting["org_name"], code: code, minutes: VALIDITY.in_minutes.to_i)
    return :sent if Sms::Gateway.deliver(to: phone, text: text).success?

    record.destroy!
    :delivery_failed
  end

  def self.verify(phone:, code:)
    record = for_phone(phone).order(created_at: :desc).first
    return :expired unless record&.usable?

    record.with_lock do
      if !record.usable?
        :expired
      elsif ActiveSupport::SecurityUtils.secure_compare(record.code_digest, digest("code", phone, code.to_s.gsub(/\s/, "")))
        record.update!(consumed_at: Time.current)
        :verified
      else
        record.increment!(:attempts)
        :invalid
      end
    end
  end

  def self.rate_limited?(phone, ip)
    recent = for_phone(phone).where("created_at > ?", 1.hour.ago)
    return true if recent.where("created_at > ?", RESEND_COOLDOWN.ago).exists?
    return true if recent.count >= MAX_PER_PHONE_PER_HOUR
    return false if ip.blank?

    where(ip_digest: digest("ip", ip)).where("created_at > ?", 1.hour.ago).count >= MAX_PER_IP_PER_HOUR
  end

  def self.digest(*parts)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, ["phone_sign_in", *parts].join(":"))
  end

  def usable?
    consumed_at.nil? && expires_at.future? && attempts < MAX_ATTEMPTS
  end
end
