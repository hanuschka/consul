class PointOfInterestCategorySerializer < BaseSerializer
  attr_reader :category

  def initialize(category)
    @category = category
  end

  def serialize
    category_data = category.as_json(
      only: [
        :id,
        :name,
        :color,
        :icon,
        :projekt_phase_id,
        :created_at,
        :updated_at
      ]
    )

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

    if category.respond_to?(:projekt_point_of_interest_pins)
      category_data[:pins_count] = category.projekt_point_of_interest_pins.count
    end

    category_data
  end

  def self.serialize_collection(categories)
    categories.map { |category| new(category).serialize }
  end
end

