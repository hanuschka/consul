class Api::DeficiencyReportCategoriesController < Api::BaseController
  def index
    check_read_access!
    categories = DeficiencyReport::Category
      .includes(:deficiency_reports)
      .page(params[:page])
      .per(params[:per_page] || 100)
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

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end
