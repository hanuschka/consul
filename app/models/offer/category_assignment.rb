class Offer::CategoryAssignment < ApplicationRecord
  belongs_to :offer, inverse_of: :category_assignments
  belongs_to :category, class_name: "Offer::Category",
    foreign_key: :offer_category_id, inverse_of: :category_assignments

  validates :offer_category_id, uniqueness: { scope: :offer_id }
end
