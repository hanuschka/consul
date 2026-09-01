class DeficiencyReport::Subcategory < ApplicationRecord
  translates :name, touch: true
  include Globalizable

  attr_accessor :default_officer_id, :default_officer_group_id

  belongs_to :category, class_name: "DeficiencyReport::Category",
    foreign_key: :deficiency_report_category_id, inverse_of: :subcategories
  belongs_to :default_responsible, polymorphic: true
  has_many :deficiency_reports, foreign_key: :deficiency_report_subcategory_id

  default_scope { order(given_order: :asc) }

  validates_translation :name, presence: true

  def self.order_subcategories(ordered_array)
    ordered_array.each_with_index do |subcategory_id, order|
      find(subcategory_id).update_column(:given_order, (order + 1))
    end
  end

  def safe_to_destroy?
    !deficiency_reports.exists?
  end
end
