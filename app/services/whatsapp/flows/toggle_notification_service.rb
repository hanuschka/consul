class Whatsapp::Flows::ToggleNotificationService < Whatsapp::Flows::BaseService
  # One tap on one row of the settings list. Flips the column and re-sends the
  # list so the citizen sees the glyph they just changed — the list itself is
  # the only feedback WhatsApp can give here.
  def initialize(conversation:, type:)
    super(conversation: conversation)
    @type = type.to_s.to_sym
  end

  def call
    return if !Whatsapp::Account::NOTIFICATION_TYPES.include?(@type)

    account.toggle_notification!(@type)

    Whatsapp::Flows::NotificationSettingsService.call(conversation: @conversation)
  end
end
