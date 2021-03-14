require_dependency Rails.root.join("app", "models", "debate").to_s

class Debate
  include Imageable

  has_and_belongs_to_many :projekts
end
