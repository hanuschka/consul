class AgeRange < ApplicationRecord
  # A blank bound is open ended, so an admin can express "under 18" or "65+"
  # without inventing a 0 or an arbitrary upper age.
  UNBOUNDED_MIN_AGE = 0
  UNBOUNDED_MAX_AGE = 200

  translates :name, touch: true
  include Globalizable

  has_many :age_range_projekt_phases, dependent: :destroy
  has_many :projekt_phases, through: :age_range_projekt_phases

  has_many :age_restricted_projekt_phases, class_name: "ProjektPhase",
                                           inverse_of: :age_restriction, dependent: :nullify

  validates :min_age, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }
  validates :max_age, numericality: { only_integer: true, greater_than_or_equal_to: 0, allow_nil: true }

  default_scope { order(order: :asc) }

  scope :for_restrictions, -> { where(only_for_stats: false) }
  scope :for_stats, -> { where(only_for_stats: true) }

  def self.order_records(ordered_array)
    ordered_array.each_with_index do |record_id, order|
      find(record_id).update_column(:order, (order + 1))
    end
  end

  def effective_min_age
    min_age || UNBOUNDED_MIN_AGE
  end

  def effective_max_age
    max_age || UNBOUNDED_MAX_AGE
  end

  def range_label
    if min_age && max_age
      "#{min_age} - #{max_age}"
    elsif max_age
      "≤ #{max_age}"
    elsif min_age
      "≥ #{min_age}"
    else
      "—"
    end
  end
end
