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

  ANALYSIS_STALL_AFTER = 15.minutes

  IN_PROGRESS_STATUSES = %w[pending extracting processing chatting submitting].freeze
  ANALYZING_STATUSES = %w[pending extracting processing].freeze

  scope :in_progress, -> { where(status: IN_PROGRESS_STATUSES) }
  scope :for_listing, -> { order(updated_at: :desc) }

  def analyzing?
    status.in?(ANALYZING_STATUSES)
  end

  def stalled?
    return false if !analyzing?

    updated_at < ANALYSIS_STALL_AFTER.ago
  end

  def created_projekts
    return Projekt.none if created_projekt_ids.blank?

    Projekt.where(id: created_projekt_ids)
  end

  def record_created_projekt!(projekt)
    ids = (created_projekt_ids + [projekt.id]).uniq

    update!(created_projekt_ids: ids, projekt_id: projekt.id)
  end

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
