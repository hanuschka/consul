class Whatsapp::Steps::ListProjektsService < ApplicationService
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    Whatsapp::Steps::SendListService.call(
      conversation: @conversation,
      rows: rows,
      body: I18n.t("whatsapp.bot.menu.projekts.body"),
      button_label: I18n.t("whatsapp.bot.menu.projekts.button"),
      empty_body: I18n.t("whatsapp.bot.menu.projekts.empty")
    )
  end

  private

    # A tap opens the projekt's card rather than its page: a projekt is a place
    # with phases, contributions and dates in it, and the page link is one of
    # the things the card offers.
    def rows
      WhatsappBrowsableProjektsQuery.call.map do |projekt|
        {
          id: Whatsapp::MenuActions.id_for(scope: :projekt, action: :card, record_id: projekt.id),
          title: Whatsapp::ProjektLink.title(projekt),
          description: projekt.page&.subtitle
        }
      end
    end
end
