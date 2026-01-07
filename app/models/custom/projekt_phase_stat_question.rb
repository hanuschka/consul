class ProjektPhaseStatQuestion < ApplicationRecord
  belongs_to :projekt_phase

  enum status: {
    pending: 0,
    processing: 1,
    completed: 2,
    failed: 3
  }

  validates :question, presence: true
  validates :projekt_phase, presence: true

  scope :by_newest, -> { order(created_at: :desc) }
  scope :answered, -> { where(status: :completed) }
end
