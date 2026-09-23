class MitmachboxParticipation < ApplicationRecord
  belongs_to :projekt_phase
  belongs_to :user

  validates :survey_version_id, presence: true
  validates :user_id, uniqueness: { scope: [:projekt_phase_id, :survey_version_id] }
end
