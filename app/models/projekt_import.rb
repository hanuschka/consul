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
  }

  ANALYSIS_STALL_AFTER = 15.minutes

  IN_PROGRESS_STATUSES = %w[pending extracting processing chatting submitting].freeze
  ANALYZING_STATUSES = %w[pending extracting processing].freeze

  FAILURE_STAGES = %w[
    extract ai_processing finalize resolve_content_blocks
    create_projekt image_generation unknown
  ].freeze

  ERROR_BACKTRACE_LINES = 15

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

  def mark_failed!(message, stage: nil, exception: nil, details: {})
    merged = (error_details.presence || {}).merge(details.to_h.stringify_keys)

    if exception
      merged = merged.merge(
        "error_class" => exception.class.name,
        "backtrace" => Array(exception.backtrace).first(ERROR_BACKTRACE_LINES)
      )
    end

    update!(
      status: "failed",
      failure_stage: (stage || failure_stage || status).to_s,
      error_message: message.to_s,
      error_details: merged
    )
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

  def self.default_content_locale
    Rails.env.development? ? I18n.locale.to_s : "de"
  end

  def import_locale
    content_locale.presence || self.class.default_content_locale
  end

  def import_response_language
    import_locale.to_s.start_with?("de") ? "German" : "English"
  end
end
