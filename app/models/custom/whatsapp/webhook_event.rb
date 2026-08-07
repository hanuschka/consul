class Whatsapp::WebhookEvent < ApplicationRecord
  scope :older_than, ->(timestamp) { where(created_at: ...timestamp) }

  def mark_processed!
    update!(processed_at: Time.current)
  end
end
