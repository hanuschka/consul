class Whatsapp::SendCtaUrlService < ApplicationService
  def initialize(account:, body:, button_label:, url:)
    @account = account
    @body = body
    @button_label = button_label
    @url = url
  end

  def call
    return if !Whatsapp::ServiceWindow.deliverable?(@account, "interactive")

    response =
      WhatsappApi::Client
        .new
        .messages
        .send_cta_url(
          to: @account.wa_id,
          body: @body,
          button_label: @button_label,
          url: @url
        )

    WhatsappMessage.record_outbound!(account: @account, kind: "interactive", body: @body, response:)
  end
end
