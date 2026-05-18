class ProjektEvaluation < ApplicationRecord
  belongs_to :projekt
  has_many :projekt_phase_evaluations, dependent: :destroy

  enum status: {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }

  enum pdf_formatted_status: {
    pdf_processing: "processing",
    pdf_completed: "completed",
    pdf_failed: "failed"
  }, _prefix: true

  validates :projekt, presence: true

  scope :by_newest, -> { order(generated_at: :desc) }

  def generate_share_token!
    return if share_token.present?

    update!(share_token: SecureRandom.urlsafe_base64(16))
  end

  def phases_data
    phase_rows.pluck(:data)
  end

  def phase_rows
    projekt_phase_evaluations
      .joins(:projekt_phase)
      .includes(:projekt_phase)
      .where("data->>'phase_type' IS NOT NULL")
      .order(Arel.sql("projekt_phases.given_order ASC NULLS LAST, projekt_phases.id ASC"))
  end

  def pdf_formatting_in_progress?
    pdf_formatted_status_pdf_processing?
  end

  def pdf_formatting_ready?
    pdf_formatted_status_pdf_completed? &&
      pdf_formatted_html.present? &&
      !pdf_formatting_stale?
  end

  def pdf_formatting_stale?
    return true if pdf_formatted_data_fingerprint != current_data_fingerprint
    return true if phase_rows.any?(&:pdf_formatting_stale?)

    false
  end

  def current_data_fingerprint
    Digest::SHA256.hexdigest(data.to_json)
  end
end
