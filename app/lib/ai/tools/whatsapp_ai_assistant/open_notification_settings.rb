class Ai::Tools::WhatsappAiAssistant::OpenNotificationSettings <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Sends the citizen the list of notification types they can switch on and off. " \
              "Use it whenever they ask about notifications, want fewer or different messages, " \
              "or want to change what they are told about. Do not use it for stopping all " \
              "messages — that is stop_messages. This sends the message itself."

  def execute
    return not_linked_error if user.blank?

    ::Whatsapp::Flows::NotificationSettingsService.call(conversation: conversation)

    halt("Sent the notification settings list.")
  end

  private

    def not_linked_error
      { error: "This number is not linked to an account, so there are no personal notification " \
               "settings yet. Offer to link the account first." }
    end
end
