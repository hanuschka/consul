# Persists /api request timings asynchronously. Api::BaseController#append_info_to_payload
# tags the process_action payload with :api_request_log for requests that should be
# logged; this subscriber reads the total/db/view runtimes Rails exposes there and
# enqueues the persistence + DT push. monotonic_subscribe keeps the duration immune
# to wall-clock shifts.
ActiveSupport::Notifications.monotonic_subscribe("process_action.action_controller") do |_name, started, finished, _id, payload|
  meta = payload[:api_request_log]

  if meta
    begin
      ApiRequestLogs::CreateAndPushJob.perform_later(
        http_method: payload[:method],
        request_path: payload[:path].to_s.split("?", 2).first,
        full_url: meta[:full_url],
        query_params: meta[:query_params],
        body_params: meta[:body_params],
        response_status: payload[:status],
        api_client_id: meta[:api_client_id],
        duration_ms: ((finished - started) * 1000).round(2),
        db_runtime: payload[:db_runtime]&.round(2),
        view_runtime: payload[:view_runtime]&.round(2)
      )
    rescue StandardError => e
      Rails.logger.error("[ApiRequestLog] Failed to enqueue log: #{e.message}")
    end
  end
end
