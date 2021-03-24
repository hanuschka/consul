require_dependency Rails.root.join("app", "models", "budget").to_s

class Budget < ApplicationRecord
  has_and_belongs_to_many :projekts
end
