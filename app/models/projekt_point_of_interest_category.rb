class ProjektPointOfInterestCategory < ApplicationRecord
  belongs_to :projekt_phase
  has_many :projekt_point_of_interest_pins

  validates :name, presence: true
  validates :color, presence: true
  validates :icon, presence: true

  scope :ordered, -> { order(name: :asc) }
end
