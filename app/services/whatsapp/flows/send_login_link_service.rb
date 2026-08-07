class Whatsapp::Flows::SendLoginLinkService < ApplicationService
  def initialize(conversation:)
    @conversation = conversation
  end

  # Catalog A2. Linking is the step the whole catalog depends on, so a button
  # that WhatsApp refuses for any reason falls back to the plain link rather
  # than to silence — with its own copy, because the fallback has to say what
  # the link is for without a button to name it.
  def call
    link_url = Whatsapp::LinkTokenService.call(account: @conversation.whatsapp_account)
    @conversation.update!(step: "awaiting_link")

    Whatsapp::Flows::SendLinkButtonService.call(
      conversation: @conversation,
      body: I18n.t("whatsapp.bot.onboarding.login_prompt"),
      url: link_url,
      button_label: I18n.t("whatsapp.bot.buttons.login"),
      fallback_body: I18n.t("whatsapp.bot.onboarding.login_prompt_with_url", url: link_url)
    )
  end
end
