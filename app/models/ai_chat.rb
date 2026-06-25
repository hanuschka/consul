class AiChat < ApplicationRecord
  belongs_to :resource, polymorphic: true
  has_many :ai_chat_messages, dependent: :destroy
end
