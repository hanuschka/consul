class Whatsapp::SendTestMessageService < ApplicationService
  def initialize(phone:, body:)
    @phone = phone.to_s.gsub(/\D/, "")
    @body = body
  end

  def call
    return blank_phone_result if @phone.blank?
    return missing_credentials_result if !::Whatsapp.configured?

    response = WhatsappApi::Client.new.messages.send_text(to: @phone, body: @body)

    record_against_known_account(response)

    build_result(response)
  rescue StandardError => e
    exception_label = I18n.t("adm.whatsapp.test_message.details.exception")

    failure(
      I18n.t("adm.whatsapp.test_message.failed"),
      exception_label => "#{e.class}: #{e.message}"
    )
  end

  private

    def build_result(response)
      details = response.technical_details

      if response.success?
        message_id_label = I18n.t("adm.whatsapp.test_message.details.message_id")

        return {
          ok: true,
          message: I18n.t("adm.whatsapp.test_message.sent", phone: @phone),
          details: details.merge(message_id_label => response.message_id.to_s)
        }
      end

      failure(I18n.t("adm.whatsapp.test_message.failed"), details)
    end

    def blank_phone_result
      failure(I18n.t("adm.whatsapp.test_message.phone_missing"))
    end

    def missing_credentials_result
      missing_secrets_label = I18n.t("adm.whatsapp.test_message.details.missing_secrets")

      failure(
        I18n.t("adm.whatsapp.not_configured"),
        missing_secrets_label => ::Whatsapp.missing_required_credential_keys.join(", ")
      )
    end

    def failure(message, details = {})
      { ok: false, message: message, details: details }
    end

    def record_against_known_account(response)
      account = WhatsappAccount.find_by(wa_id: @phone)

      return if account.blank?

      WhatsappMessage.record_outbound!(account:, kind: "text", body: @body, response:)
    end
end
