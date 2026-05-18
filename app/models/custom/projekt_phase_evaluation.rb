class ProjektPhaseEvaluation < ApplicationRecord
  belongs_to :projekt_evaluation
  belongs_to :projekt_phase

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

  validates :projekt_evaluation, presence: true
  validates :projekt_phase, presence: true
  validates :projekt_phase_id, uniqueness: { scope: :projekt_evaluation_id }

  scope :by_phase_id, ->(id) { where(projekt_phase_id: id) }

  def pdf_formatting_in_progress?
    pdf_formatted_status_pdf_processing?
  end

  def pdf_formatting_ready?
    pdf_formatted_html.present? && !pdf_formatting_stale?
  end

  def pdf_formatting_stale?
    pdf_formatted_data_fingerprint != current_data_fingerprint
  end

  def current_data_fingerprint
    Digest::SHA256.hexdigest(data.to_json)
  end

  def cached_chunk_html(chunk_key)
    return nil if pdf_formatted_html.blank?

    parsed = JSON.parse(pdf_formatted_html)
    parsed[chunk_key.to_s]
  rescue JSON::ParserError
    nil
  end

  def write_chunk_cache!(chunks_by_key)
    update!(
      pdf_formatted_html: chunks_by_key.to_json,
      pdf_formatted_status: "completed",
      pdf_formatted_at: Time.current,
      pdf_formatted_data_fingerprint: current_data_fingerprint,
      pdf_formatted_error: nil
    )
  end
end
