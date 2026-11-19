class Api::DeficiencyReportCategoriesController < Api::BaseController
  def index
    check_read_access!
    categories = paginate(DeficiencyReport::Category.includes(:translations, :default_responsible))
    reports_counts = DeficiencyReport
      .admin_accepted
      .where(deficiency_report_category_id: categories.map(&:id))
      .group(:deficiency_report_category_id)
      .count
    serialized_categories = DeficiencyReportCategorySerializer.serialize_collection(
      categories,
      client: current_client,
      reports_counts: reports_counts
    )

    render json: {
      data: { deficiency_report_categories: serialized_categories },
      pagination: pagination_meta(categories)
    }
  end
end
