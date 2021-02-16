require_dependency Rails.root.join("app", "models", "debate").to_s

class Debate
  include Imageable

  MANAGE_CATEGORIES    = 0b110
  MANAGE_SUBCATEGORIES = 0b110

  TAGS_PREDEFINED = 0b001
  TAGS_CLOUD      = 0b010
  TAGS_CUSTOM     = 0b100

  def self.category_predefined?
    MANAGE_CATEGORIES & TAGS_PREDEFINED > 0
  end
  def self.subcategory_predefined?
    MANAGE_SUBCATEGORIES & TAGS_PREDEFINED > 0
  end
end
