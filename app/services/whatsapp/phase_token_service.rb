class Whatsapp::PhaseTokenService < ApplicationService
  PREFIX = "WB".freeze
  DIGEST_LENGTH = 6
  TOKEN_PATTERN = /\b#{PREFIX}-(\d+)-([0-9a-f]{#{DIGEST_LENGTH}})\b/i.freeze

  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def call
    "#{PREFIX}-#{@projekt_phase.id}-#{self.class.digest_for(@projekt_phase.id)}"
  end

  def self.projekt_phase_id_from(text)
    match = TOKEN_PATTERN.match(text.to_s)

    return if match.blank?

    projekt_phase_id = match[1]

    return if !ActiveSupport::SecurityUtils.secure_compare(
      match[2].downcase, digest_for(projekt_phase_id)
    )

    projekt_phase_id.to_i
  end

  def self.digest_for(projekt_phase_id)
    OpenSSL::HMAC
      .hexdigest("SHA256", Rails.application.secret_key_base, "whatsapp-phase-#{projekt_phase_id}")
      .first(DIGEST_LENGTH)
  end
end
