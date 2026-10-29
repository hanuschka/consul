load Rails.root.join("app", "models", "tag_cloud.rb")

class TagCloud
  def tags
    resource_model.
    last_week.tag_counts.
    where("lower(name) NOT IN (?)", category_names + geozone_names + default_blacklist).
    order("#{table_name}_count": :desc, name: :asc).
    limit(10)
  end
end
