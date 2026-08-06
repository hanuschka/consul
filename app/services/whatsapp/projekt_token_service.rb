class Whatsapp::ProjektTokenService < ApplicationService
  PREFIX = "WP".freeze
  SCOPE = "projekt".freeze
  TOKEN_PATTERN = /\b#{PREFIX}-(\d+)-([0-9a-f]{#{Whatsapp::TokenDigest::LENGTH}})\b/i.freeze

  def initialize(projekt:)
    @projekt = projekt
  end

  def call
    "#{PREFIX}-#{@projekt.id}-#{Whatsapp::TokenDigest.for(SCOPE, @projekt.id)}"
  end

  def self.projekt_id_from(text)
    match = TOKEN_PATTERN.match(text.to_s)

    return if match.blank?
    return if !Whatsapp::TokenDigest.valid?(SCOPE, match[1], match[2])

    match[1].to_i
  end
end
