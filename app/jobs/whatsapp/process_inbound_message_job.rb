class Whatsapp::ProcessInboundMessageJob < ApplicationJob
  queue_as :default

  CONTENDED_RETRY_DELAY = 5.seconds

  def perform(whatsapp_message_id, raw_message = {})
    whatsapp_message = Whatsapp::Message.find_by(id: whatsapp_message_id)

    return if whatsapp_message.blank?

    # Two messages from the same number are two independent jobs. Without this
    # they read-modify-write the same conversation step concurrently, which can
    # publish one draft twice.
    handled = Whatsapp::ConversationLock.hold(conversation_id_for(whatsapp_message)) do
      I18n.with_locale(locale_for(whatsapp_message)) do
        Whatsapp::ProcessInboundMessageService.call(whatsapp_message:, raw_message:)
      end
    end

    return if handled

    self.class.set(wait: CONTENDED_RETRY_DELAY).perform_later(whatsapp_message_id, raw_message)
  end

  private

    def conversation_id_for(whatsapp_message)
      whatsapp_message.whatsapp_account.conversation.id
    end

    def locale_for(whatsapp_message)
      user_locale = whatsapp_message.whatsapp_account.user&.locale.to_s

      return ::Whatsapp.default_locale if !I18n.available_locales.map(&:to_s).include?(user_locale)

      user_locale
    end
end
