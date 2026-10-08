class Api::DeficiencyReportCategoriesController < Api::BaseController
  def index
    check_read_access!
    categories = paginate(DeficiencyReport::Category.includes(:deficiency_reports))
    serialized_categories = DeficiencyReportCategorySerializer.serialize_collection(categories)
    render json: {
      data: { deficiency_report_categories: serialized_categories },
      pagination: pagination_meta(categories)
    }
  end

  private

  def find_deficiency_report_category
    @deficiency_report_category = DeficiencyReport::Category.find(params[:id])
  end
end
