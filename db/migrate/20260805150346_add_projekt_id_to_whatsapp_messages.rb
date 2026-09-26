class AddProjektIdToWhatsappMessages < ActiveRecord::Migration[6.1]
  def change
    add_column :whatsapp_messages, :projekt_id, :integer

    add_index :whatsapp_messages, [:whatsapp_account_id, :projekt_id, :kind],
      name: "index_whatsapp_messages_on_account_projekt_kind"
  end
end
