class DeficiencyReport::Category < ApplicationRecord
  include Iconable

  translates :name, touch: true
  include Globalizable

  has_many :deficiency_reports, foreign_key: :deficiency_report_category_id

  default_scope { order(given_order: :asc) }

  def safe_to_destroy?
    !deficiency_reports.exists?
  end

  def self.order_categories(ordered_array)
    ordered_array.each_with_index do |category_id, order|
      find(category_id).update_column(:given_order, (order + 1))
    end
  end
end
