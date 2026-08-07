class Whatsapp::Archive::SendPhaseResultsService < ApplicationService
  def initialize(conversation:, projekt_phase:)
    @conversation = conversation
    @projekt_phase = projekt_phase
  end

  # Re-asked rather than trusted: the row may have been sent before the team
  # withdrew the evaluation, and a hidden evaluation must not stay reachable
  # through an old message.
  def call
    return send_gone if Whatsapp::PublishedResultsQuery.public_section_for(@projekt_phase).blank?

    ::Whatsapp::Flows::SendLinkButtonService.call(
      conversation: @conversation,
      body: I18n.t("whatsapp.archive.menu.results.link_body", phase: @projekt_phase.title),
      url: Whatsapp::ProjektLink.evaluation_url(@projekt_phase)
    )
  end

  private

    def send_gone
      ::Whatsapp::Archive::MainMenuService.call(
        conversation: @conversation,
        body: I18n.t("whatsapp.archive.menu.link.gone")
      )
    end
end
