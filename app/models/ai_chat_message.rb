class AiChatMessage < ApplicationRecord
  belongs_to :ai_chat
  belongs_to :user_message, class_name: "AiChatMessage", optional: true

  enum role: {
    system: "system",
    user: "user",
    assistant: "assistant"
  }, _prefix: true

  enum status: {
    scheduled: "scheduled",
    running: "running",
    completed: "completed",
    error: "error"
  }, _prefix: true

  def from_user?
    role == "user"
  end

  def from_ai?
    role == "assistant"
  end
end
