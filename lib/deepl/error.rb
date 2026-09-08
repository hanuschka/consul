module Deepl
  class Error < StandardError
    attr_reader :http_status, :api_message

    def initialize(message = nil, http_status: nil, api_message: nil)
      @http_status = http_status
      @api_message = api_message

      super(message || api_message || default_message)
    end

    class << self
      def from_response(response)
        class_for_status(response.code).new(
          http_status: response.code,
          api_message: parse_message(response)
        )
      end

      def class_for_status(status)
        case status.to_i
        when 400 then Deepl::BadRequestError
        when 401, 403 then Deepl::AuthError
        when 404 then Deepl::NotFoundError
        when 413, 414 then Deepl::RequestTooLargeError
        when 429 then Deepl::RateLimitError
        when 456 then Deepl::QuotaExceededError
        when 503 then Deepl::ServiceUnavailableError
        else Deepl::ApiError
        end
      end

      def parse_message(response)
        parsed = response.parsed_response

        parsed.is_a?(Hash) ? parsed["message"] : nil
      rescue StandardError
        nil
      end
    end

    private

      def default_message
        if http_status.present?
          "DeepL API error (HTTP #{http_status})"
        else
          "DeepL API error"
        end
      end
  end

  class ConfigurationError < Error; end
  class ConnectionError < Error; end
  class CircuitOpenError < Error; end
  class UnsupportedLanguageError < Error; end
  class BadRequestError < Error; end
  class AuthError < Error; end
  class NotFoundError < Error; end
  class RequestTooLargeError < Error; end
  class RateLimitError < Error; end
  class QuotaExceededError < Error; end
  class ServiceUnavailableError < Error; end
  class ApiError < Error; end
end
