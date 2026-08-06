# Resolves a signed QR token back to the record it points at, so a poster
# request cannot be pointed at an arbitrary projekt by editing the URL.
class Whatsapp::QrTokenSubjectService < ApplicationService
  def initialize(token:)
    @token = token.to_s
  end

  def call
    projekt_phase_id = Whatsapp::PhaseTokenService.projekt_phase_id_from(@token)

    return ProjektPhase.find_by(id: projekt_phase_id) if projekt_phase_id.present?

    projekt_id = Whatsapp::ProjektTokenService.projekt_id_from(@token)

    return if projekt_id.blank?

    Projekt.find_by(id: projekt_id)
  end
end
