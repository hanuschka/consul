class Whatsapp::Steps::SendPhaseResultsService < ApplicationService
  def initialize(conversation:, projekt_phase:)
    @conversation = conversation
    @projekt_phase = projekt_phase
  end

  # Re-asked rather than trusted: the row may have been sent before the team
  # withdrew the evaluation, and a hidden evaluation must not stay reachable
  # through an old message.
  def call
    return send_gone if WhatsappPublishedResultsQuery.public_section_for(@projekt_phase).blank?

    Whatsapp::Steps::SendLinkButtonService.call(
      conversation: @conversation,
      body: I18n.t("whatsapp.bot.menu.results.link_body", phase: @projekt_phase.title),
      url: Whatsapp::ProjektLink.evaluation_url(@projekt_phase)
    )
  end

  private

    def send_gone
      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: I18n.t("whatsapp.bot.menu.link.gone"),
        actions: [:menu]
      )
    end
end
