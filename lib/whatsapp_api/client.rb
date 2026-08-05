class WhatsappApi::Client
  include HTTParty

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
      response = WhatsappApi::Response.new(yield)

      if !response.success?
        WhatsappApi::ErrorReporter.report_error(response, context:)
      end

      response
    rescue StandardError => e
      WhatsappApi::ErrorReporter.report_exception(e, context:)
      raise
    end

    def json_headers
      { headers: auth_header.merge("Content-Type" => "application/json") }
    end

    def auth_header
      { "D360-API-KEY" => ::Whatsapp.api_key.to_s }
    end
end
