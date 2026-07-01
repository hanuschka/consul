class ApiRequestLogs::CreateAndPushJob < ApplicationJob
  queue_as :default

  def perform(http_method:, request_path:, full_url:, query_params:, body_params:, response_status:, api_client_id:, duration_ms: nil, db_runtime: nil, view_runtime: nil)
    log = ApiRequestLog.create!(
      http_method: http_method,
      request_path: request_path,
      full_url: full_url,
      query_params: query_params,
      body_params: body_params,
      response_status: response_status,
      api_client_id: api_client_id,
      duration_ms: duration_ms,
      db_runtime: db_runtime,
      view_runtime: view_runtime
    )

    push_to_dt(log)
  rescue => e
    Rails.logger.error("[ApiRequestLog] Failed to create/push log: #{e.message}")
  end

  private

  def push_to_dt(log)
    return unless Dt.connected?

    DtApi::Client
      .new
      .consul_api_request_logs
      .create(
        http_method: log.http_method,
        request_path: log.request_path,
        full_url: log.full_url,
        query_params: log.query_params,
        body_params: log.body_params,
        response_status: log.response_status,
        duration_ms: log.duration_ms,
        db_runtime: log.db_runtime,
        view_runtime: log.view_runtime,
        consul_api_client_name: log.api_client&.name,
        logged_at: log.created_at.iso8601
      )

  rescue => e
    Rails.logger.error("[ApiRequestLog] Failed to push log #{log.id} to DT: #{e.message}")
  end
end
