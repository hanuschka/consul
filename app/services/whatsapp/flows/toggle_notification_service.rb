class Whatsapp::Flows::ToggleNotificationService < ApplicationService
  # One tap on one row of the settings list. Flips the column and re-sends the
  # list so the citizen sees the glyph they just changed — the list itself is
  # the only feedback WhatsApp can give here.
  def initialize(conversation:, type:)
    @conversation = conversation
    @type = type.to_s.to_sym
  end

  def call
    return if !Whatsapp::Account::NOTIFICATION_TYPES.include?(@type)

    @conversation.whatsapp_account.toggle_notification!(@type)

    Whatsapp::Flows::NotificationSettingsService.call(conversation: @conversation)
  end
end
