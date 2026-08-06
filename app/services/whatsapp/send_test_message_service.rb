class Whatsapp::SendTestMessageService < ApplicationService
  def initialize(phone:, body:)
    @phone = phone.to_s.gsub(/\D/, "")
    @body = body
  end

  def call
    return if @phone.blank?

    response = WhatsappApi::Client.new.messages.send_text(to: @phone, body: @body)

    record_against_known_account(response)

    response
  end

  private

    def record_against_known_account(response)
      account = WhatsappAccount.find_by(wa_id: @phone)

      return if account.blank?

      WhatsappMessage.record_outbound!(account:, kind: "text", body: @body, response:)
    end
end
