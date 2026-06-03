class ProjektImport < ApplicationRecord
  belongs_to :user
  belongs_to :projekt, optional: true

  has_one :ai_chat, as: :resource, dependent: :destroy
  has_many_attached :source_files

  enum status: {
    pending: "pending",
    extracting: "extracting",
    processing: "processing",
    chatting: "chatting",
    submitting: "submitting",
    completed: "completed",
    failed: "failed",
    abandoned: "abandoned"
  }

  enum image_status: {
    image_pending: "pending",
    image_running: "running",
    image_completed: "completed",
    image_failed: "failed",
    image_skipped: "skipped"
  }, _prefix: :image

  def mark_failed!(message)
    update!(status: "failed", error_message: message.to_s)
  end

  def mark_abandoned!
    update!(status: "abandoned")
  end

  def add_warning!(message)
    self.warnings = (warnings || []) + [{
      "message" => message.to_s,
      "at" => Time.current.iso8601
    }]
    save!
  end

  def terminal?
    status.in?(%w[completed failed abandoned])
  end
end
