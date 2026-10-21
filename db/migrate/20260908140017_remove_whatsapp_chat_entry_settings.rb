class RemoveWhatsappChatEntrySettings < ActiveRecord::Migration[6.1]
  KEYS = %w[
    whatsapp.welcome_message_enabled
    whatsapp.welcome_greeting
    whatsapp.ice_breaker_1
    whatsapp.ice_breaker_2
    whatsapp.ice_breaker_3
    whatsapp.ice_breaker_4
    whatsapp.commands
  ].freeze

  # The connection page's chat-entry section and the service behind it are gone,
  # so nothing reads or seeds these keys any more. Left in place they would show
  # up in no admin screen while still being editable through the attribute
  # endpoint, so they are removed rather than kept as unreachable rows.
  def up
    Setting.where(key: KEYS).delete_all
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
