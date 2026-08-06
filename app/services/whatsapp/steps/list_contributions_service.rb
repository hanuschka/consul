class Whatsapp::Steps::ListContributionsService < ApplicationService
  MAX_SHOWN = 5

  # Answered as text rather than as a list: a row would have to lead somewhere,
  # and the only thing to lead to is the link the text already carries.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    return send_empty if contributions.empty?

    Whatsapp::Outbound.recovery(
      conversation: @conversation,
      body: [I18n.t("whatsapp.bot.menu.contributions.intro"), *entries].join("\n\n"),
      actions: [:menu]
    )
  end

  private

    def account
      @conversation.whatsapp_account
    end

    def contributions
      @contributions ||= WhatsappUserContributionsQuery.call(user: account.user)
    end

    def entries
      contributions.first(MAX_SHOWN).map do |resource|
        I18n.t(
          "whatsapp.bot.menu.contributions.entry",
          title: resource.title,
          url: Whatsapp::PublishedResourceUrl.call(resource)
        )
      end
    end

    def send_empty
      Whatsapp::Outbound.recovery(
        conversation: @conversation,
        body: I18n.t("whatsapp.bot.menu.contributions.empty"),
        actions: [:menu]
      )
    end
end
