class Admin::ApiRequestLogsController < Admin::BaseController
  def index
    @api_request_logs = ApiRequestLog.order(created_at: :desc).page(params[:page]).per(50)
  end

  def show
    @api_request_log = ApiRequestLog.find(params[:id])
  end
end
