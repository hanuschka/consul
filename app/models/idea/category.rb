class Idea::Category < ApplicationRecord
  include Iconable

  translates :name, touch: true
  include Globalizable

  has_many :ideas, foreign_key: :idea_category_id, inverse_of: :category
  belongs_to :default_idea_officer, class_name: "Idea::Officer", foreign_key: :idea_officer_id, optional: true

  default_scope { order(given_order: :asc) }

  def safe_to_destroy?
    !ideas.exists?
  end

  def self.order_categories(ordered_array)
    ordered_array.each_with_index do |category_id, order|
      find(category_id).update_column(:given_order, (order + 1))
    end
  end
end
