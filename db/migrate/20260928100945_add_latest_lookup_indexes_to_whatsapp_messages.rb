class AddLatestLookupIndexesToWhatsappMessages < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :whatsapp_messages, [:whatsapp_account_id, :id],
      order: { id: :desc },
      where: "direction = 'outbound' AND language IS NOT NULL",
      name: "index_whatsapp_messages_on_account_latest_reply_language",
      algorithm: :concurrently

    add_index :whatsapp_messages, [:whatsapp_account_id, :id],
      order: { id: :desc },
      where: "direction = 'inbound'",
      name: "index_whatsapp_messages_on_account_latest_inbound",
      algorithm: :concurrently
  end
end
