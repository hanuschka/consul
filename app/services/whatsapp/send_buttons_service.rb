class Whatsapp::SendButtonsService < ApplicationService
  def initialize(account:, body:, buttons:)
    @account = account
    @body = body
    @buttons = buttons
  end

  def call
    return if !Whatsapp::ServiceWindow.deliverable?(@account, "interactive")

    response =
      WhatsappApi::Client
        .new
        .messages
        .send_buttons(to: @account.wa_id, body: @body, buttons: @buttons)

    WhatsappMessage.record_outbound!(account: @account, kind: "interactive", body: @body, response:)
  end
end
