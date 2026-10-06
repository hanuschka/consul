class CreateWhatsappMessages < ActiveRecord::Migration[6.1]
  def change
    create_table :whatsapp_messages do |t|
      t.integer :whatsapp_account_id, null: false
      t.string :direction, null: false
      t.string :kind, null: false, default: "text"
      t.text :body
      t.string :wa_message_id
      t.string :status
      t.datetime :sent_at
      t.jsonb :error, null: false, default: {}

      t.timestamps
    end

    add_index :whatsapp_messages, :whatsapp_account_id
    add_index :whatsapp_messages, :wa_message_id, unique: true
    add_index :whatsapp_messages, :created_at
  end
end
