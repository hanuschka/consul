class Whatsapp::PhaseTokenService < ApplicationService
  PREFIX = "WB".freeze
  SCOPE = "phase".freeze
  TOKEN_PATTERN = /\b#{PREFIX}-(\d+)-([0-9a-f]{#{Whatsapp::TokenDigest::LENGTH}})\b/i.freeze

  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def call
    "#{PREFIX}-#{@projekt_phase.id}-#{Whatsapp::TokenDigest.for(SCOPE, @projekt_phase.id)}"
  end

  def self.projekt_phase_id_from(text)
    match = TOKEN_PATTERN.match(text.to_s)

    return if match.blank?
    return if !Whatsapp::TokenDigest.valid?(SCOPE, match[1], match[2])

    match[1].to_i
  end
end
