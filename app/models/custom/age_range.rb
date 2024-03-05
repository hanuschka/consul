class AgeRange < ApplicationRecord
  translates :name, touch: true
  include Globalizable

  has_many :age_range_projekt_phases, dependent: :destroy
  has_many :projekt_phases, through: :age_range_projekt_phases

  has_many :age_restricted_projekt_phases, class_name: "ProjektPhase",
                                           inverse_of: :age_restriction, dependent: :nullify

  default_scope { order(order: :asc) }

  scope :for_restrictions, -> { where(only_for_stats: false) }
  scope :for_stats, -> { where(only_for_stats: true) }

  def self.order_records(ordered_array)
    ordered_array.each_with_index do |record_id, order|
      find(record_id).update_column(:order, (order + 1))
    end
  end
end
