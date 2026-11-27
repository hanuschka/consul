class DeficiencyReportCategorySerializer < BaseSerializer
  attr_reader :category

  def initialize(category, client: nil, deficiency_reports_count: nil)
    @category = category
    @client = client
    @deficiency_reports_count = deficiency_reports_count
  end

  def serialize
    category_data = category.as_json(
      only: [
        :id,
        :created_at,
        :updated_at,
        :given_order,
        :icon,
        :color,
        :warning_text
      ]
    )

    category_data.merge!(
      name: category.name,
      translations: serialize_translations(category)
    )

    if admin_client? && category.default_responsible.present?
      category_data[:default_responsible] = {
        id: category.default_responsible.id,
        type: category.default_responsible_type,
        name: category.default_responsible.name
      }
    end

    category_data[:deficiency_reports_count] =
      @deficiency_reports_count || category.deficiency_reports.admin_accepted.count

    category_data
  end

  def self.serialize_collection(categories, client: nil, reports_counts: {})
    categories.map do |category|
      new(
        category,
        client: client,
        deficiency_reports_count: reports_counts.fetch(category.id, 0)
      ).serialize
    end
  end
end
