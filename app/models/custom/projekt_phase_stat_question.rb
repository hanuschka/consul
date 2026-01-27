class ProjektPhaseStatQuestion < ApplicationRecord
  belongs_to :projekt_phase

  enum status: {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }

  validates :question, presence: true
  validates :projekt_phase, presence: true

  scope :by_newest, -> { order(created_at: :desc) }
  scope :answered, -> { where(status: :completed) }
end
