require_dependency Rails.root.join("app", "models", "proposal").to_s
class Proposal < ApplicationRecord
  MANAGE_CATEGORIES    = 0b110
  MANAGE_SUBCATEGORIES = 0b010

  TAGS_PREDEFINED = 0b001
  TAGS_CLOUD      = 0b010
  TAGS_CUSTOM     = 0b100
end