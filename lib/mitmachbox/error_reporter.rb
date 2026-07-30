module Mitmachbox::ErrorReporter
  module_function

  SILENCED_STATUSES = [404, 409, 422].freeze

  def report_error(response, context:)
    endpoint = response.request&.uri.to_s

    Rails.logger.error(
      "[Mitmachbox] API error: #{response.code} for #{endpoint} (context: #{context})"
    )

    return if SILENCED_STATUSES.include?(response.code.to_i)
    return unless sentry_enabled?

    Sentry.capture_message(
      "Mitmachbox API Error",
      level: :error,
      fingerprint: ["mitmachbox-api-error", context],
      extra: {
        status_code: response.code,
        response_body: response.body,
        endpoint:,
        context:
      }
    )
  end

  def report_exception(exception, context:)
    Rails.logger.error(
      "[Mitmachbox] Connection error: #{exception.class} for #{context}"
    )

    return unless sentry_enabled?

    Sentry.capture_exception(
      exception,
      fingerprint: ["mitmachbox-api-error", context],
      extra: {
        endpoint: context,
        error_type: "connection_error"
      }
    )
  end

  def sentry_enabled?
    Mitmachbox.config[:report_errors_to_sentry].present?
  end
end
