class Whatsapp::Steps::ListProjektsService < ApplicationService
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    return send_empty if projekts.empty?

    Whatsapp::Outbound.list(
      account: @conversation.whatsapp_account,
      body: I18n.t("whatsapp.bot.menu.projekts.body"),
      button_label: I18n.t("whatsapp.bot.menu.projekts.button"),
      rows: rows
    )
  end

  private

    def projekts
      @projekts ||= WhatsappBrowsableProjektsQuery.call
    end

    def rows
      projekts.map do |projekt|
        {
          id: Whatsapp::MenuActions.projekt_row_id_for(projekt.id),
          title: projekt_title(projekt),
          description: projekt.page&.subtitle
        }
      end
    end

    def projekt_title(projekt)
      projekt.page&.title.presence || projekt.name
    end

    def send_empty
      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: I18n.t("whatsapp.bot.menu.projekts.empty"),
        actions: [:menu]
      )
    end
end
