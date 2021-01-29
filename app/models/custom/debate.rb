require_dependency Rails.root.join("app", "models", "debate").to_s
class Debate < ApplicationRecord
  MANAGE_CATEGORIES    = 0b110
  MANAGE_SUBCATEGORIES = 0b001

  TAGS_PREDEFINED = 1
  TAGS_CLOUD      = 2
  TAGS_CUSTOM     = 4
end