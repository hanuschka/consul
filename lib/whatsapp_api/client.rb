class WhatsappApi::Client
  include HTTParty

  AUTH_HEADER_NAME = "D360-API-KEY".freeze
  RETRY_AFTER_HEADER = "retry-after".freeze
  RETRYABLE_CODES = [429, 500, 502, 503, 504].freeze
  MAX_ATTEMPTS = 3
  BASE_BACKOFF = 1.second
  MAX_BACKOFF = 30.seconds

  base_uri ::Whatsapp.base_url.to_s
  default_timeout 20

  if Rails.application.secrets.web_server_proxy.present?
    proxy_config = Rails.application.secrets.web_server_proxy
    if proxy_config[:address].present?
      http_proxy(
        proxy_config[:address],
        proxy_config[:port],
        proxy_config[:username],
        proxy_config[:password]
      )
    end
  end

  def messages
    @messages ||= WhatsappApi::Resources::Messages.new(self)
  end

  def media
    @media ||= WhatsappApi::Resources::Media.new(self)
  end

  def webhooks
    @webhooks ||= WhatsappApi::Resources::Webhooks.new(self)
  end

  def templates
    @templates ||= WhatsappApi::Resources::Templates.new(self)
  end

  def conversational_automation
    @conversational_automation ||= WhatsappApi::Resources::ConversationalAutomation.new(self)
  end

  def get(path, query: nil)
    wrap_with_response_object(path) do
      self.class.get(path, query:, **json_headers)
    end
  end

  def post(path, body:)
    wrap_with_response_object(path) do
      self.class.post(path, body: body.to_json, **json_headers)
    end
  end

  def delete(path)
    wrap_with_response_object(path) do
      self.class.delete(path, **json_headers)
    end
  end

  def download(absolute_url)
    wrap_with_response_object(absolute_url) do
      self.class.get(absolute_url, headers: auth_header)
    end
  end

  private

    def wrap_with_response_object(context)
      response = nil

      MAX_ATTEMPTS.times do |attempt|
        response = WhatsappApi::Response.new(yield)

        break if !retryable?(response)
        break if attempt == MAX_ATTEMPTS - 1

        sleep(retry_delay(response, attempt))
      end

      if !response.success?
        WhatsappApi::ErrorReporter.report_error(response, context:)
      end

      response
    rescue StandardError => e
      WhatsappApi::ErrorReporter.report_exception(e, context:)
      raise
    end

    # Rate limits and gateway hiccups are the two failures a resend can fix; a
    # 4xx about the message itself would only be rejected again.
    def retryable?(response)
      RETRYABLE_CODES.include?(response.code.to_i)
    end

    def retry_delay(response, attempt)
      requested_delay = response.headers[RETRY_AFTER_HEADER].to_i

      return requested_delay.clamp(1, MAX_BACKOFF) if requested_delay.positive?

      BASE_BACKOFF * (2**attempt)
    end

    def json_headers
      { headers: auth_header.merge("Content-Type" => "application/json") }
    end

    def auth_header
      { AUTH_HEADER_NAME => ::Whatsapp.api_key.to_s }
    end
end
