class DeficiencyReport::Category < ApplicationRecord
  include Iconable

  translates :name, touch: true
  include Globalizable

  attr_accessor :default_officer_id, :default_officer_group_id

  has_many :deficiency_reports, foreign_key: :deficiency_report_category_id
  has_many :subcategories, class_name: "DeficiencyReport::Subcategory",
    foreign_key: :deficiency_report_category_id, inverse_of: :category, dependent: :destroy
  belongs_to :default_responsible, polymorphic: true

  default_scope { order(given_order: :asc) }

  after_save :unset_other_ai_fallbacks, if: :ai_fallback?

  # Where a report lands when AI categorization is on but produced nothing usable. Falls back to the
  # first category so the feature still has somewhere to put a report before anybody marks one.
  def self.ai_fallback
    find_by(ai_fallback: true) || first
  end

  def safe_to_destroy?
    !deficiency_reports.exists?
  end

  def self.order_categories(ordered_array)
    ordered_array.each_with_index do |category_id, order|
      find(category_id).update_column(:given_order, (order + 1))
    end
  end

  private

    def unset_other_ai_fallbacks
      self.class.unscoped.where.not(id: id).update_all(ai_fallback: false)
    end
end
