class Adm::ApiRequestLogsController < Adm::BaseController
  def index
    scope = policy_scope(ApiRequestLog, policy_scope_class: Adm::ApiRequestLogPolicy::Scope)
    filtered = Adm::ApiRequestLogsQuery.call(scope.includes(:api_client), params)

    @pagy, @api_request_logs = pagy(filtered.order(created_at: :desc), items: 50)

    @logs_present = ApiRequestLog.exists?
    assign_filter_options

    @breadcrumbs = [
      { name: t("adm.api_request_logs.index.title"), icon: "terminal" }
    ]
  end

  def destroy_all
    authorize [:adm, ApiRequestLog.new], :destroy_all?, policy_class: Adm::ApiRequestLogPolicy
    ApiRequestLog.delete_all

    redirect_to adm_api_request_logs_path, notice: t("adm.api_request_logs.destroy_all.success")
  end

  def show
    @api_request_log = ApiRequestLog.find(params[:id])
    authorize [:adm, @api_request_log], policy_class: Adm::ApiRequestLogPolicy

    @breadcrumbs = [
      { name: t("adm.api_request_logs.index.title"), icon: "terminal", url: adm_api_request_logs_path },
      { name: "##{@api_request_log.id}" }
    ]
  end

  private

    def assign_filter_options
      @http_method_options = ApiRequestLog::HTTP_METHOD_BADGE_VARIANTS.keys
      @response_status_options = ApiRequestLog
        .where.not(response_status: nil)
        .distinct
        .order(:response_status)
        .pluck(:response_status)
      @api_client_options = ApiClient.order(:name).pluck(:name, :id)
    end
end
