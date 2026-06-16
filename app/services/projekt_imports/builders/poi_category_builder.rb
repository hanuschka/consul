class ProjektImports::Builders::PoiCategoryBuilder < ProjektImports::Builders::Base
  def call
    Array(payload).filter_map do |cat|
      next nil if cat["name"].blank?

      phase.projekt_point_of_interest_categories.create!(
        name: cat["name"],
        color: cat["color"].presence || "#3388ff",
        icon: cat["icon"].presence || "place"
      )
    rescue ActiveRecord::RecordInvalid => e
      raise ProjektImports::Builders::BuilderError, "poi_category(#{cat['name']}): #{e.message}"
    end
  end
end
