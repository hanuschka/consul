class Whatsapp::SendTextService < ApplicationService
  def initialize(account:, body:)
    @account = account
    @body = body
  end

  def call
    return if !Whatsapp::ServiceWindow.deliverable?(@account, "text")

    response = WhatsappApi::Client.new.messages.send_text(to: @account.wa_id, body: @body)

    WhatsappMessage.record_outbound!(account: @account, kind: "text", body: @body, response:)
  end
end
