class Whatsapp::ProcessInboundMessageJob < ApplicationJob
  queue_as :default

  def perform(whatsapp_message_id, raw_message = {})
    whatsapp_message = WhatsappMessage.find_by(id: whatsapp_message_id)

    return if whatsapp_message.blank?

    I18n.with_locale(locale_for(whatsapp_message)) do
      Whatsapp::ProcessInboundMessageService.call(whatsapp_message:, raw_message:)
    end
  end

  private

    def locale_for(whatsapp_message)
      user_locale = whatsapp_message.whatsapp_account.user&.locale.to_s

      return I18n.default_locale if !I18n.available_locales.map(&:to_s).include?(user_locale)

      user_locale
    end
end
