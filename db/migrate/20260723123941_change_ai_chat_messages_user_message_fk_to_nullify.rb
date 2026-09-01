class ChangeAiChatMessagesUserMessageFkToNullify < ActiveRecord::Migration[6.1]
  def up
    remove_foreign_key :ai_chat_messages, column: :user_message_id
    add_foreign_key :ai_chat_messages, :ai_chat_messages,
                    column: :user_message_id, on_delete: :nullify
  end

  def down
    remove_foreign_key :ai_chat_messages, column: :user_message_id
    add_foreign_key :ai_chat_messages, :ai_chat_messages, column: :user_message_id
  end
end
