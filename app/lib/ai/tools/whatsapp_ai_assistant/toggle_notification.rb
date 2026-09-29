class Ai::Tools::WhatsappAiAssistant::ToggleNotification <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Switches one kind of notification on or off. Pass the type exactly as " \
              "my_notification_settings returned it, and only for the ones the citizen actually " \
              "asked to change. A tapped notify_enable button means on and notify_disable means " \
              "off; for a notify_toggle button or a typed request, call " \
              "my_notification_settings first and pass the direction they asked for. " \
              "This is not about stopping all messages, which is stop_messages. Sends nothing; " \
              "say what is now on."

  SWITCH_ON = "on".freeze
  SWITCH_OFF = "off".freeze
  SWITCHES = [SWITCH_ON, SWITCH_OFF].freeze

  # A direction rather than a flip. A flip is answered by whatever the setting is
  # when the call arrives, so a citizen who tapped the same switch twice while the
  # reply was on its way had it turned on by the first tap and off again by the
  # second. Constrained in the schema for the reason ManageSubscription gives: the
  # provider cannot emit a third value.
  params(
    type: "object",
    properties: {
      type: {
        type: "string",
        description: "The notification type, exactly as my_notification_settings returned it"
      },
      switch: {
        type: "string",
        enum: SWITCHES,
        description: "Whether to switch the notification on or off"
      }
    },
    required: %w[type switch],
    additionalProperties: false
  )

  def diagnostic_step
    ::Whatsapp::Conversation::Step::AWAITING_NOTIFICATION_SETTINGS
  end

  def execute(type:, switch:)
    return not_linked_error("have notification settings") if user.blank?

    notification_type = ::Whatsapp::Account::NOTIFICATION_TYPES.find do |known|
      known.to_s == type.to_s
    end

    return unknown_type_error if notification_type.blank?
    return unclear_switch_error if !SWITCHES.include?(switch.to_s)

    was_enabled = account.notifies?(notification_type)

    apply(notification_type, switch.to_s)

    enabled = account.notifies?(notification_type)
    changed = enabled != was_enabled

    if changed
      conversation.note_action_completed!(
        ::Whatsapp::CompletedAction.notification_switched(
          notification_type: notification_type, enabled: enabled
        )
      )
    end

    {
      type: notification_type.to_s,
      enabled: enabled,
      changed: changed,
      hint: "Say which one it is and whether it is now on or off — if nothing changed, that " \
            "it already was. Do not list the rest."
    }
  end

  private

    def apply(notification_type, switch)
      if switch == SWITCH_ON
        account.enable_notification!(notification_type)
      else
        account.disable_notification!(notification_type)
      end
    end

    def unknown_type_error
      { error: "There is no notification of that kind. Call my_notification_settings for the " \
               "ones that exist." }
    end

    # The enum should make this unreachable; it stands as the floor for a provider
    # that does not enforce schemas.
    def unclear_switch_error
      { error: "switch must be exactly \"on\" or \"off\". Ask the citizen which of the two " \
               "they meant rather than calling this again with a guess." }
    end
end
