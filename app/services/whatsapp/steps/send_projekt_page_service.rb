class Whatsapp::Steps::SendProjektPageService < ApplicationService
  def initialize(conversation:, projekt:)
    @conversation = conversation
    @projekt = projekt
  end

  def call
    Whatsapp::Steps::SendLinkButtonService.call(
      conversation: @conversation,
      body: I18n.t(
        "whatsapp.bot.menu.link.body", title: Whatsapp::ProjektLink.title(@projekt)
      ),
      url: Whatsapp::ProjektLink.url(@projekt)
    )
  end
end
