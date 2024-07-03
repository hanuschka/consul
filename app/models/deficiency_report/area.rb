class DeficiencyReport::Area < ApplicationRecord
  has_many :deficiency_reports, dependent: :restrict_with_exception,
    foreign_key: :deficiency_report_area_id, inverse_of: :area
  has_one :map_location, foreign_key: :deficiency_report_area_id, inverse_of: :deficiency_report_area, dependent: :destroy

  accepts_nested_attributes_for :map_location, update_only: true

  def safe_to_destroy?
    deficiency_reports.none?
  end

  def self.order_areas(ordered_array)
    ordered_array.each_with_index do |area_id, order|
      find(area_id).update_column(:given_order, (order + 1))
    end
  end
end
