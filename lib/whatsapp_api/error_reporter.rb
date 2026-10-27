module WhatsappApi::ErrorReporter
  module_function

  def report_error(response, context:)
    Rails.logger.error(
      "[WhatsappApi] API error: #{response.code} for #{context}"
    )

    Sentry.capture_message(
      "WhatsApp API Error",
      level: :error,
      fingerprint: ["whatsapp-api-error", context],
      extra: {
        status_code: response.code,
        response_body: response.body.to_s.first(2000),
        context:
      }
    )
  end

  def report_exception(exception, context:)
    Rails.logger.error(
      "[WhatsappApi] Connection error: #{exception.class} for #{context}"
    )

    Sentry.capture_exception(
      exception,
      fingerprint: ["whatsapp-api-connection-error", context],
      extra: {
        context:,
        error_type: "connection_error"
      }
    )
  end
end
