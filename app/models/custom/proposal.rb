require_dependency Rails.root.join("app", "models", "proposal").to_s
class Proposal < ApplicationRecord

  has_and_belongs_to_many :projekts
end
