class InternalApi::ApiRequestLogsController < InternalApi::BaseController
  def destroy_bad
    deleted_count = ApiRequestLog.where(response_status: 404).delete_all

    render json: { deleted_count: deleted_count }, status: :ok
  end
end
