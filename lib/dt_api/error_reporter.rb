module DtApi::ErrorReporter
  module_function

  def report_error(response, context:)
    return unless sentry_enabled?

    endpoint = response.request.uri.to_s

    Rails.logger.error(
      "[DtApi] API error: #{response.code} for #{endpoint} (context: #{context})"
    )

    Sentry.capture_message(
      "DT API Error",
      level: :error,
      fingerprint: ["dt-api-error", context],
      extra: {
        status_code: response.code,
        response_body: response.body,
        endpoint:,
        context:
      }
    )
  end

  def report_exception(exception, context:)
    return unless sentry_enabled?

    Rails.logger.error(
      "[DtApi] Connection error: #{exception.class} for #{context}"
    )

    Sentry.capture_exception(
      exception,
      fingerprint: ["dt-api-connection-error", context],
      extra: {
        endpoint: context,
        error_type: "connection_error"
      }
    )
  end

  def sentry_enabled?
    Rails.application.secrets.dt[:report_errors_to_sentry].present?
  end
end
