class Whatsapp::SendListService < ApplicationService
  def initialize(account:, body:, button_label:, rows:)
    @account = account
    @body = body
    @button_label = button_label
    @rows = rows
  end

  def call
    response =
      WhatsappApi::Client
        .new
        .messages
        .send_list(
          to: @account.wa_id,
          body: @body,
          button_label: @button_label,
          rows: @rows
        )

    WhatsappMessage.record_outbound!(account: @account, kind: "interactive", body: @body, response:)
  end
end
