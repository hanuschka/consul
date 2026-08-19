class Ai::Tools::WhatsappAiAssistant::ToggleNotification <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Switches one kind of notification on or off — it flips whatever it currently is, " \
              "so call my_notification_settings first and only call this for the ones the " \
              "citizen actually asked to change. Pass the type exactly as that tool returned it. " \
              "This is not about stopping all messages, which is stop_messages. Sends nothing; " \
              "say what is now on."

  params do
    string :type,
      description: "The notification type, exactly as my_notification_settings returned it"
  end

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_NOTIFICATION_SETTINGS
  end

  def execute(type:)
    return not_linked_error("have notification settings") if user.blank?

    notification_type = ::Whatsapp::Account::NOTIFICATION_TYPES.find do |known|
      known.to_s == type.to_s
    end

    return unknown_type_error if notification_type.blank?

    account.toggle_notification!(notification_type)

    {
      type: notification_type.to_s,
      enabled: account.notifies?(notification_type),
      hint: "Say which one changed and whether it is now on or off. Do not list the rest."
    }
  end

  private

    def unknown_type_error
      { error: "There is no notification of that kind. Call my_notification_settings for the " \
               "ones that exist." }
    end
end
