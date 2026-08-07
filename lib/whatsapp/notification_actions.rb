module Whatsapp::NotificationActions
  # Handled before the step dispatcher and before the assistant, like the
  # recovery buttons: turning messages off is the one instruction that must work
  # from any state and must never depend on a model reading it correctly.
  BUTTON_IDS = {
    messages_off: "whatsapp_messages_off",
    messages_on: "whatsapp_messages_on"
  }.freeze

  module_function

  def action_from(button_reply_id)
    BUTTON_IDS.key(button_reply_id.to_s)
  end
end
