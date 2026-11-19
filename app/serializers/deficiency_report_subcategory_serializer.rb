class DeficiencyReportSubcategorySerializer < BaseSerializer
  attr_reader :subcategory

  def initialize(subcategory)
    @subcategory = subcategory
  end

  def serialize
    subcategory
      .as_json(only: [:id, :deficiency_report_category_id, :given_order, :created_at, :updated_at])
      .merge(
        name: subcategory.name,
        translations: serialize_translations(subcategory)
      )
  end
end
