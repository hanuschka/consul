class PollManagerAssignment < ApplicationRecord
  belongs_to :poll
  belongs_to :poll_manager

  validates :poll_id, presence: true
  validates :poll_manager_id, presence: true
  validates :poll_id, uniqueness: { scope: :poll_manager_id }
end
