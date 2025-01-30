class OfficingManagerAssignment < ApplicationRecord
  belongs_to :projekt_phase
  belongs_to :officing_manager

  validates :projekt_phase_id, presence: true
  validates :officing_manager_id, presence: true
  validates :projekt_phase_id, uniqueness: { scope: :officing_manager_id }
end
