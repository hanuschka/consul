class ProjektEvaluation < ApplicationRecord
  belongs_to :projekt
  has_many :projekt_phase_evaluations, dependent: :destroy

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

  def phases_data
    phase_rows.map(&:data)
  end

  def phase_rows
    @phase_rows ||= projekt_phase_evaluations
      .joins(:projekt_phase)
      .where("data->>'phase_type' IS NOT NULL")
      .order(Arel.sql("projekt_phases.given_order ASC NULLS LAST, projekt_phases.id ASC"))
      .to_a
  end
end
