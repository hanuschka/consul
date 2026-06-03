class AiChat < ApplicationRecord
  belongs_to :resource, polymorphic: true
  has_many :ai_chat_messages, dependent: :destroy

  def last_assistant_message
    ai_chat_messages.where(role: "assistant").order(created_at: :asc).last
  end
end
