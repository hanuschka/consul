class Ai::Tools::WhatsappAiAssistant::MyNotificationSettings <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Returns which kinds of message this citizen currently gets and which they do not, " \
              "each with the action id that switches it. Call it whenever they ask about " \
              "notifications or want fewer or different messages — you cannot know what is on " \
              "without asking. Sends nothing: say what is on and offer the switches with " \
              "send_list. This is not about stopping all messages, which is stop_messages."

  def execute
    return not_linked_error("have notification settings") if user.blank?

    { notifications: ::Whatsapp::Account::NOTIFICATION_TYPES.map { |type| row_for(type) }}
  end

  private

    # The action id travels with each row so the model never composes one: what the
    # citizen taps is the id this read handed over, which is also the id the
    # dispatcher re-resolves against the known types.
    def row_for(type)
      {
        name: I18n.t("whatsapp.bot.notifications.types.#{type}.short"),
        about: I18n.t("whatsapp.bot.notifications.types.#{type}.label"),
        enabled: account.notifies?(type),
        action_id: "notify_toggle-#{type}"
      }
    end
end
