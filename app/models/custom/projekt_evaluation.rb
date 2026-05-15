class ProjektEvaluation < ApplicationRecord
  belongs_to :projekt

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

  def phase_data_for(projekt_phase)
    return {} if data.blank?

    phases = data["phases"] || []
    phases.find { |p| p["phase_id"] == projekt_phase.id } || {}
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
    pdf_formatted_data_fingerprint != current_data_fingerprint
  end

  def current_data_fingerprint
    Digest::SHA256.hexdigest(data.to_json)
  end
end
