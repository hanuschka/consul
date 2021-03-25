require_dependency Rails.root.join("app", "models", "tag_cloud").to_s
class TagCloud
  def category_names
    Tag.category_names.map(&:downcase)
  end
end
