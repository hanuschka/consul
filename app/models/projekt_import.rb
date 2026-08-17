class ProjektImport < ApplicationRecord
  belongs_to :user
  belongs_to :projekt, optional: true

  has_one :ai_chat, as: :resource, dependent: :destroy
  has_many_attached :source_files

  # The pictures found inside the source documents, extracted once during
  # analysis so the admin can look at them and choose a title image before the
  # projekt exists. Ordered by attachment id, which is the document order they
  # were attached in, and described in the source_images column alongside.
  has_many_attached :extracted_images

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

  # What the projekt's title image will be. "document" is the default and means
  # one of the pictures in the uploaded files — which one is title_image_index,
  # preset to the best candidate and overridable by the admin in the chat.
  enum title_image_mode: {
    document: "document",
    generated: "generated",
    none: "none"
  }, _prefix: :title_image

  ANALYSIS_STALL_AFTER = 15.minutes

  ANALYSIS_WARNING_STAGE = "analysis".freeze
  SUBMIT_WARNING_STAGE = "submit".freeze

  # Marks the one chat message that renders the title image picker instead of
  # text, reusing the column the Summarize and Regenerate buttons already use to
  # say what produced a message.
  TITLE_IMAGE_PICKER_COMMAND = "title_image_picker".freeze

  # Stamped on a user message that was a bare option number rather than something
  # to send to the model, for the same reason the Summarize and Regenerate buttons
  # stamp theirs: it applied a change, so it must not be counted as an unanswered
  # request when the projekt is created.
  TITLE_IMAGE_REPLY_COMMAND = "title_image_reply".freeze

  IN_PROGRESS_STATUSES = %w[pending extracting processing chatting submitting].freeze
  ANALYZING_STATUSES = %w[pending extracting processing].freeze

  FAILURE_STAGES = %w[
    extract ai_processing resolve_content_blocks
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

  # One tile in the chat's title image picker: what the picture is, whether it
  # can legally become a title image, and the attachment to render it from.
  SourceImageCandidate = Struct.new(
    :index, :filename, :source_filename, :width, :height,
    :eligible, :ineligible_reason, :attachment,
    keyword_init: true
  )

  # The attachments are loaded in one query rather than one per tile, and matched
  # to their descriptor by blob id so a purged attachment yields a candidate
  # without a picture instead of shifting every later tile onto the wrong image.
  def source_image_candidates
    return @source_image_candidates if @source_image_candidates.present?

    attachments_by_blob_id = extracted_images.includes(:blob).index_by(&:blob_id)

    @source_image_candidates = Array(source_images).each_with_index.map do |descriptor, index|
      SourceImageCandidate.new(
        index: index,
        filename: descriptor["filename"],
        source_filename: descriptor["source_filename"],
        width: descriptor["width"],
        height: descriptor["height"],
        eligible: descriptor["eligible"],
        ineligible_reason: descriptor["ineligible_reason"],
        attachment: attachments_by_blob_id[descriptor["blob_id"]]
      )
    end
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

  def add_warning!(message, stage: SUBMIT_WARNING_STAGE)
    self.warnings = (warnings || []) + [{
      "message" => message.to_s,
      "stage" => stage,
      "at" => Time.current.iso8601
    }]
    save!
  end

  # A warning raised while the documents were being analysed is about the
  # uploaded files themselves — an image that cannot be read stays unreadable
  # however often the projekt is submitted — so it survives the reset that clears
  # the previous submit attempt's warnings.
  def analysis_warnings
    Array(warnings).select { |warning| warning["stage"] == ANALYSIS_WARNING_STAGE }
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
