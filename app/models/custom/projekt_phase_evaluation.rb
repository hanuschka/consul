class ProjektPhaseEvaluation < ApplicationRecord
  belongs_to :projekt_evaluation
  belongs_to :projekt_phase

  enum status: {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }

  validates :projekt_evaluation, presence: true
  validates :projekt_phase, presence: true
  validates :projekt_phase_id, uniqueness: { scope: :projekt_evaluation_id }

  scope :by_phase_id, ->(id) { where(projekt_phase_id: id) }

  def ai_content?
    info = data || {}

    info["ai_stats"].present? ||
      info["evaluation_summary"].present? ||
      info["key_findings"].present?
  end
end
