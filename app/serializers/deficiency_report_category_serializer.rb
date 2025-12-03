class DeficiencyReportCategorySerializer < BaseSerializer
  attr_reader :category

  def initialize(category)
    @category = category
  end

  def serialize
    category_data = category.as_json(
      only: [
        :id,
        :created_at,
        :updated_at,
        :given_order,
        :icon,
        :color
      ]
    )

    category_data.merge!(
      name: category.name
    )

    if category.default_responsible.present?
      category_data[:default_responsible] = {
        id: category.default_responsible.id,
        type: category.default_responsible_type,
        name: category.default_responsible.name
      }
    end

    category_data[:deficiency_reports_count] = category.deficiency_reports.count

    category_data
  end

  def self.serialize_collection(categories)
    categories.map { |category| new(category).serialize }
  end
end
