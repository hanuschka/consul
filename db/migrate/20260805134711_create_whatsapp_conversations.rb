class CreateWhatsappConversations < ActiveRecord::Migration[6.1]
  def change
    create_table :whatsapp_conversations do |t|
      t.integer :whatsapp_account_id, null: false
      t.string :step, null: false, default: "idle"
      t.integer :projekt_phase_id
      t.integer :proposal_id
      t.jsonb :context, null: false, default: {}
      t.integer :revisions_count, null: false, default: 0
      t.datetime :last_inbound_at

      t.timestamps
    end

    add_index :whatsapp_conversations, :whatsapp_account_id, unique: true
    add_index :whatsapp_conversations, :projekt_phase_id
    add_index :whatsapp_conversations, :proposal_id
  end
end
