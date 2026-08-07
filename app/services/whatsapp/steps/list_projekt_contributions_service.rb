class Whatsapp::Steps::ListProjektContributionsService < ApplicationService
  def initialize(conversation:, projekt:)
    @conversation = conversation
    @projekt = projekt
  end

  def call
    Whatsapp::Steps::SendDigestService.call(
      conversation: @conversation,
      entries: Whatsapp::ProjektContributionsQuery.call(projekt: @projekt),
      intro: I18n.t(
        "whatsapp.bot.menu.projekt_contributions.intro",
        projekt: Whatsapp::ProjektLink.title(@projekt)
      ),
      empty_body: I18n.t("whatsapp.bot.menu.projekt_contributions.empty"),
      more_url: Whatsapp::ProjektLink.url(@projekt)
    )
  end
end
