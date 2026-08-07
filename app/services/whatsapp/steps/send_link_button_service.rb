class Whatsapp::Steps::SendLinkButtonService < ApplicationService
  # Every "here is a page to open" reply. A button WhatsApp refuses for any
  # reason falls back to the plain link rather than to silence, the same way the
  # linking invitation does.
  def initialize(conversation:, body:, url:, button_label: nil)
    @conversation = conversation
    @body = body
    @url = url
    @button_label = button_label
  end

  def call
    message = Whatsapp::Outbound.cta_url(
      account: account,
      body: @body,
      button_label: @button_label || I18n.t("whatsapp.bot.buttons.open_projekt"),
      url: @url
    )

    return message if message&.status == "sent"

    Whatsapp::Outbound.text(account: account, body: "#{@body}\n\n#{@url}")
  end

  private

    def account
      @conversation.whatsapp_account
    end
end
