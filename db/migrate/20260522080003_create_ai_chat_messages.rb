class CreateAiChatMessages < ActiveRecord::Migration[6.1]
  def change
    create_table :ai_chat_messages do |t|
      t.references :ai_chat, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content
      t.string :status, null: false, default: "scheduled"
      t.jsonb :attached_documents, null: false, default: []
      t.string :custom_command
      t.references :user_message,
        foreign_key: { to_table: :ai_chat_messages }, null: true
      t.timestamps
    end

    add_index :ai_chat_messages, [:ai_chat_id, :created_at]
  end
end
