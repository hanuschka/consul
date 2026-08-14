module Whatsapp::QrToken
  # Printed on posters and typed back by WhatsApp when a QR deep link is
  # scanned, so the token has to survive being embedded in free text: a prefix
  # to spot it by, the record id, and a digest that stops the id from being
  # edited into a projekt the poster never pointed at.
  PROJEKT_PHASE_PREFIX = "WB".freeze
  PROJEKT_PREFIX = "WP".freeze
  PROJEKT_PHASE_SCOPE = "phase".freeze
  PROJEKT_SCOPE = "projekt".freeze

  DIGEST_LENGTH = 6
  DIGEST_PATTERN = "[0-9a-f]{#{DIGEST_LENGTH}}".freeze
  PROJEKT_PHASE_PATTERN = /\b#{PROJEKT_PHASE_PREFIX}-(\d+)-(#{DIGEST_PATTERN})\b/i.freeze
  PROJEKT_PATTERN = /\b#{PROJEKT_PREFIX}-(\d+)-(#{DIGEST_PATTERN})\b/i.freeze

  module_function

  def for_projekt_phase(projekt_phase)
    build(PROJEKT_PHASE_PREFIX, PROJEKT_PHASE_SCOPE, projekt_phase.id)
  end

  def for_projekt(projekt)
    build(PROJEKT_PREFIX, PROJEKT_SCOPE, projekt.id)
  end

  def projekt_phase_id_from(text)
    record_id_from(text, PROJEKT_PHASE_PATTERN, PROJEKT_PHASE_SCOPE)
  end

  def projekt_id_from(text)
    record_id_from(text, PROJEKT_PATTERN, PROJEKT_SCOPE)
  end

  def build(prefix, scope, record_id)
    "#{prefix}-#{record_id}-#{digest_for(scope, record_id)}"
  end

  def record_id_from(text, pattern, scope)
    match = pattern.match(text.to_s)

    return if match.blank?
    return if !valid_digest?(scope, match[1], match[2])

    match[1].to_i
  end

  def digest_for(scope, record_id)
    OpenSSL::HMAC
      .hexdigest("SHA256", Rails.application.secret_key_base, "whatsapp-#{scope}-#{record_id}")
      .first(DIGEST_LENGTH)
  end

  def valid_digest?(scope, record_id, digest)
    ActiveSupport::SecurityUtils.secure_compare(digest.to_s.downcase, digest_for(scope, record_id))
  end

  private_class_method :build, :record_id_from, :digest_for, :valid_digest?
end
