module Deepl
  module ErrorReporter
    module_function

    SILENCED_STATUSES = [429].freeze

    def report_error(response, context:)
      Rails.logger.error("[DeepL] API error: #{response.code} for #{context}")

      return if SILENCED_STATUSES.include?(response.code.to_i)
      return unless defined?(Sentry)

      Sentry.capture_message(
        "DeepL API Error",
        level: :error,
        fingerprint: ["deepl-api-error", context],
        extra: {
          status_code: response.code,
          response_body: response.body.to_s.first(500),
          context:
        }
      )
    end

    def report_exception(exception, context:)
      Rails.logger.error("[DeepL] Connection error: #{exception.class} for #{context}")

      return unless defined?(Sentry)

      Sentry.capture_exception(
        exception,
        fingerprint: ["deepl-connection-error", context],
        extra: {
          context:,
          error_type: "connection_error"
        }
      )
    end
  end
end
