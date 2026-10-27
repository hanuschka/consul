class MunicipalPlan::Link < ApplicationRecord
  belongs_to :municipal_plan, inverse_of: :links

  validates :title, presence: true
  validates :url, presence: true
end
