class Api::DeficiencyReportSubcategoriesController < Api::BaseController
  def index
    check_read_access!
    subcategories = DeficiencyReport::Subcategory.includes(:translations)

    if params[:category_id].present?
      subcategories = subcategories.where(deficiency_report_category_id: params[:category_id].to_s)
    end

    subcategories = paginate(subcategories)

    render json: {
      data: {
        deficiency_report_subcategories:
          DeficiencyReportSubcategorySerializer.serialize_collection(subcategories)
      },
      pagination: pagination_meta(subcategories)
    }
  end
end
