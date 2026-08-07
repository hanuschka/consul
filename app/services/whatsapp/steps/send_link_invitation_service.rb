class Whatsapp::Steps::SendLinkInvitationService < ApplicationService
  def initialize(conversation:)
    @conversation = conversation
  end

  # Linking is the step the whole flow depends on, so a button that WhatsApp
  # refuses for any reason falls back to the plain link rather than to silence
  # — the shared rule, with its own copy because the fallback has to say what
  # the link is for without a button to name it.
  def call
    link_url = Whatsapp::LinkTokenService.call(account: @conversation.whatsapp_account)
    @conversation.update!(step: "awaiting_link")

    Whatsapp::Steps::SendLinkButtonService.call(
      conversation: @conversation,
      body: I18n.t("whatsapp.bot.link_invitation"),
      url: link_url,
      button_label: I18n.t("whatsapp.bot.link_invitation_button"),
      fallback_body: I18n.t("whatsapp.bot.link_invitation_with_url", url: link_url)
    )
  end
end
