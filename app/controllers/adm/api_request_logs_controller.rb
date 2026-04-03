class Adm::ApiRequestLogsController < Adm::BaseController
  def index
    @pagy, @api_request_logs = pagy(
      policy_scope(ApiRequestLog, policy_scope_class: Adm::ApiRequestLogPolicy::Scope)
        .order(created_at: :desc),
      items: 50
    )

    @breadcrumbs = [
      { name: t("adm.api_request_logs.index.title"), icon: "terminal" }
    ]
  end

  def show
    @api_request_log = ApiRequestLog.find(params[:id])
    authorize [:adm, @api_request_log], policy_class: Adm::ApiRequestLogPolicy

    @breadcrumbs = [
      { name: t("adm.api_request_logs.index.title"), icon: "terminal", url: adm_api_request_logs_path },
      { name: "##{@api_request_log.id}" }
    ]
  end
end
