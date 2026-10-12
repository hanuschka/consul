class Api::MunicipalPlansController < Api::BaseController
  before_action :check_read_access!
  before_action :check_module_enabled!

  rescue_from MunicipalPlansApiQuery::InvalidParameter, with: :render_bad_request

  def index
    municipal_plans = MunicipalPlansApiQuery.call(params)
                                            .page(params[:page])
                                            .per(per_page)

    render json: {
      data: { municipal_plans: MunicipalPlanSerializer.serialize_collection(municipal_plans) },
      pagination: pagination_meta(municipal_plans)
    }
  end

  def show
    municipal_plan = MunicipalPlan.released_versions.published.find(params[:id])

    render json: { data: { municipal_plan: MunicipalPlanSerializer.new(municipal_plan).serialize }}
  end

  private

    def per_page
      requested = params[:per_page].to_i
      requested.positive? ? [requested, DEFAULT_PER_PAGE].min : DEFAULT_PER_PAGE
    end

    def check_module_enabled!
      raise ActiveRecord::RecordNotFound if Setting["process.municipal_plans"].blank?
    end

    def render_bad_request(exception)
      render json: { error: { type: "bad_request", messages: [exception.message] }}, status: :bad_request
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
