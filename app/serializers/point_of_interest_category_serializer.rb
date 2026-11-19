class PointOfInterestCategorySerializer < BaseSerializer
  include Rails.application.routes.url_helpers

  attr_reader :category

  def initialize(category, pins_count: nil)
    @category = category
    @pins_count = pins_count
  end

  def serialize
    category_data = category.as_json(
      only: [
        :id,
        :name,
        :color,
        :icon,
        :position,
        :projekt_phase_id,
        :created_at,
        :updated_at
      ]
    )

    category_data[:icon_image_url] = icon_image_url

    if category.projekt_phase.present?
      category_data[:projekt_phase] = {
        id: category.projekt_phase.id,
        title: category.projekt_phase.phase_tab_name,
        type: category.projekt_phase.type,
        projekt_id: category.projekt_phase.projekt_id
      }

      if category.projekt_phase.projekt.present?
        projekt = category.projekt_phase.projekt
        category_data[:projekt] = {
          id: projekt.id,
          title: projekt.page&.title || projekt.name
        }
      end
    end

    category_data[:pins_count] = @pins_count || category.projekt_point_of_interest_pins.count

    category_data
  end

  def self.serialize_collection(categories)
    pins_counts = ProjektPointOfInterestPin
      .where(projekt_point_of_interest_category_id: categories.map(&:id))
      .group(:projekt_point_of_interest_category_id)
      .count

    categories.map { |category| new(category, pins_count: pins_counts.fetch(category.id, 0)).serialize }
  end

  private

    def icon_image_url
      return if !category.icon_image.attached?

      rails_blob_url(category.icon_image, **UrlOptions.default)
    end
end
