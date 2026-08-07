class Whatsapp::Steps::ListPhaseContributionsService < ApplicationService
  def initialize(conversation:, projekt_phase:)
    @conversation = conversation
    @projekt_phase = projekt_phase
  end

  def call
    Whatsapp::Steps::SendDigestService.call(
      conversation: @conversation,
      entries: WhatsappPhaseContributionsQuery.call(projekt_phase: @projekt_phase),
      intro: I18n.t("whatsapp.bot.menu.phase_contributions.intro", phase: @projekt_phase.title),
      empty_body: I18n.t("whatsapp.bot.menu.phase_contributions.empty"),
      more_url: Whatsapp::ProjektLink.phase_url(@projekt_phase)
    )
  end
end
