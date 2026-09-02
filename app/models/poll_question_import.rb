class PollQuestionImport < ApplicationRecord
  belongs_to :projekt_phase
  belongs_to :author, class_name: "User"

  has_many_attached :source_files

  enum status: {
    pending: "pending",
    extracting: "extracting",
    processing: "processing",
    completed: "completed",
    failed: "failed",
    applied: "applied"
  }

  IN_PROGRESS_STATUSES = %w[pending extracting processing].freeze

  # The list groups applied with completed: both mean the document was read and
  # its questions are there to look at, which is the distinction the filter
  # chips make.
  FINISHED_STATUSES = %w[completed applied].freeze

  # Reading a document and asking the model about it takes well under a minute,
  # so anything still running after this has almost always lost its worker
  # rather than being slow. Deliberately shorter than the projekt import's 15
  # minutes -- that flow analyses far more -- and shorter than the preview
  # page's polling window, so the page itself can report the stall.
  ANALYSIS_STALL_AFTER = 5.minutes

  scope :in_progress, -> { where(status: IN_PROGRESS_STATUSES) }
  scope :finished, -> { where(status: FINISHED_STATUSES) }
  scope :for_listing, -> { order(created_at: :desc) }

  # Mirrors ProjektImport.default_content_locale: the generated text is German
  # everywhere except development, where the admin's own locale keeps local
  # output readable.
  def self.default_content_locale
    Rails.env.development? ? I18n.locale.to_s : "de"
  end

  # The preview lets the admin correct what the model chose, so it offers every
  # vote type the manual question form does.
  def self.vote_type_options
    VotationType.vote_types.keys.map do |vote_type|
      [I18n.t("activerecord.attributes.votation_type/vote_type.#{vote_type}"), vote_type]
    end
  end

  def analyzing?
    status.in?(IN_PROGRESS_STATUSES)
  end

  def stalled?
    return false if !analyzing?

    updated_at < ANALYSIS_STALL_AFTER.ago
  end

  # What the list and the status endpoint report, as opposed to what the column
  # holds: a stalled import is still pending or processing to the database, but
  # showing it as "in progress" forever is the whole problem being fixed.
  def display_status
    return "stalled" if stalled?

    status
  end

  def import_locale
    content_locale.presence || self.class.default_content_locale
  end

  def response_language
    Ai::OutputLanguage.name_for(import_locale)
  end

  def questions_payload
    Array(result)
  end

  def created_questions
    return Poll::Question.none if created_question_ids.blank?

    Poll::Question.where(id: created_question_ids)
  end

  def mark_failed!(message)
    update!(status: "failed", error_message: message.to_s)
  end

  def mark_applied!(questions)
    update!(status: "applied", created_question_ids: questions.map(&:id))
  end
end
