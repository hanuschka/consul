class Whatsapp::Archive::SendPhasePageService < ApplicationService
  def initialize(conversation:, projekt_phase:)
    @conversation = conversation
    @projekt_phase = projekt_phase
  end

  def call
    ::Whatsapp::Flows::SendLinkButtonService.call(
      conversation: @conversation,
      body: I18n.t("whatsapp.archive.menu.link.body", title: @projekt_phase.title),
      url: Whatsapp::ProjektLink.phase_url(@projekt_phase)
    )
  end
end
