class Whatsapp::Archive::ListPhaseContributionsService < ApplicationService
  def initialize(conversation:, projekt_phase:)
    @conversation = conversation
    @projekt_phase = projekt_phase
  end

  def call
    ::Whatsapp::Archive::SendDigestService.call(
      conversation: @conversation,
      entries: Whatsapp::PhaseContributionsQuery.call(projekt_phase: @projekt_phase),
      intro: I18n.t("whatsapp.archive.menu.phase_contributions.intro", phase: @projekt_phase.title),
      empty_body: I18n.t("whatsapp.archive.menu.phase_contributions.empty"),
      more_url: Whatsapp::ProjektLink.phase_url(@projekt_phase)
    )
  end
end
