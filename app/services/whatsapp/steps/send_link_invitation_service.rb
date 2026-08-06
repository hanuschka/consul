class Whatsapp::Steps::SendLinkInvitationService < ApplicationService
  def initialize(conversation:)
    @conversation = conversation
  end

  # Linking is the step the whole flow depends on, so a button that WhatsApp
  # refuses for any reason falls back to the plain link rather than to silence.
  def call
    link_url = Whatsapp::LinkTokenService.call(account: account)
    @conversation.update!(step: "awaiting_link")

    message = send_button(link_url)

    return message if message&.status == "sent"

    Whatsapp::Outbound.text(
      account: account,
      body: I18n.t("whatsapp.bot.link_invitation_with_url", url: link_url)
    )
  end

  private

    def send_button(link_url)
      Whatsapp::Outbound.cta_url(
        account: account,
        body: I18n.t("whatsapp.bot.link_invitation"),
        button_label: I18n.t("whatsapp.bot.link_invitation_button"),
        url: link_url
      )
    end

    def account
      @conversation.whatsapp_account
    end
end
