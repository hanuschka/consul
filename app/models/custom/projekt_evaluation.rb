class ProjektEvaluation < ApplicationRecord
  belongs_to :projekt

  enum status: {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }

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
end
