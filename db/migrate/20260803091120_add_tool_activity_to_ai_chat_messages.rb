class AddToolActivityToAiChatMessages < ActiveRecord::Migration[6.1]
  def change
    add_column :ai_chat_messages, :tool_activity, :jsonb, default: [], null: false
  end
end
