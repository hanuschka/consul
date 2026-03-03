class UserResourceCriteria < ApplicationRecord
  belongs_to :projekt_phase
  validates :text, presence: true

  default_scope { order(:position) }
end
