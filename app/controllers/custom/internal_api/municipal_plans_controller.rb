class InternalApi::MunicipalPlansController < InternalApi::BaseController
  DEFAULT_PER_PAGE = 100
  MAX_PER_PAGE = 500

  before_action :check_module_enabled!

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from MunicipalPlansApiQuery::InvalidParameter, with: :render_bad_request

  def index
    municipal_plans = MunicipalPlansApiQuery.call(params)

    if params[:page].present?
      render json: paginated_payload(municipal_plans)
    else
      render json: { municipal_plans: MunicipalPlanSerializer.serialize_collection(municipal_plans) }
    end
  end

  def show
    municipal_plan = MunicipalPlan.released_versions.published.find(params[:id])

    render json: { municipal_plan: MunicipalPlanSerializer.new(municipal_plan).serialize }
  end

  private

    def check_module_enabled!
      raise ActiveRecord::RecordNotFound if Setting["process.municipal_plans"].blank?
    end

    def paginated_payload(municipal_plans)
      page = [params[:page].to_i, 1].max
      total_count = municipal_plans.count(:all)

      {
        municipal_plans: MunicipalPlanSerializer.serialize_collection(
          municipal_plans.offset((page - 1) * per_page).limit(per_page)
        ),
        pagination: {
          page: page,
          per_page: per_page,
          total_count: total_count,
          total_pages: (total_count.to_f / per_page).ceil
        }
      }
    end

    def per_page
      requested = params[:per_page].to_i
      requested.positive? ? [requested, MAX_PER_PAGE].min : DEFAULT_PER_PAGE
    end

    def render_not_found
      render json: { error: "Not found" }, status: :not_found
    end

    def render_bad_request(exception)
      render json: { error: exception.message }, status: :bad_request
    end
end
