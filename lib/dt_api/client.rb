class DtApi::Client
  include HTTParty

  base_uri "#{Dt.url}/api"

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

  def initialize(api_token = nil, use_cache: false)
    @api_token = api_token || InternalApiClient&.dt&.service_api_token
    @use_cache = use_cache
  end

  def projekts
    @projekts ||= DtApi::Resources::Projekts.new(self)
  end

  def clients
    @clients ||= DtApi::Resources::Clients.new(self)
  end

  def consul_ai_prompts
    @consul_ai_prompts ||= DtApi::Resources::ConsulAiPrompts.new(self)
  end

  def ai_assistant_configs
    @ai_assistant_configs ||= DtApi::Resources::ClientAiAssistantConfigs.new(self)
  end

  def ai
    @ai ||= DtApi::Resources::Ai.new(self)
  end

  def voice_assistant
    @voice_assistant ||= DtApi::Resources::VoiceAssistant.new(
      self
    )
  end

  def connection
    @connection ||= DtApi::Resources::Connection.new(self)
  end

  def content_block_templates
    @content_block_templates ||= DtApi::Resources::ContentBlockTemplates.new(self)
  end

  def consul_api_request_logs
    @consul_api_request_logs ||= DtApi::Resources::ConsulApiRequestLogs.new(self)
  end

  def consul_ai_usage_records
    @consul_ai_usage_records ||= DtApi::Resources::ConsulAiUsageRecords.new(self)
  end

  def get(url, query: nil)
    if @use_cache
      return get_with_cache(url, query:)
    end

    wrap_with_response_object(url) do
      self.class.get(url, query:, **base_headers, **auth_settings)
    end
  end

  def post(url, body:, multipart: false)
    wrap_with_response_object(url) do
      self.class.post(url, multipart:, **base_headers, **auth_settings, body:)
    end
  end

  def patch(url, body:, multipart: false)
    wrap_with_response_object(url) do
      self.class.patch(url, multipart:, **base_headers, **auth_settings, body:)
    end
  end

  def delete(url)
    wrap_with_response_object(url) do
      self.class.delete(url, **base_headers, **auth_settings)
    end
  end

  private

    def get_with_cache(url, query:)
      cache_key = DtApi::Caching.build_cache_key(url, query)

      begin
        response = self.class.get(url, query:, **base_headers, **auth_settings)
      rescue => e
        DtApi::ErrorReporter.report_exception(e, context: cache_key)

        return DtApi::Response.new(
          nil,
          cached_response: DtApi::Caching.cached_response_or_raise(cache_key, e)
        )
      end

      if response.success?
        DtApi::Caching.update_cache_if_different(cache_key, response.parsed_response)

        DtApi::Response.new(response)
      else
        DtApi::ErrorReporter.report_error(response, context: cache_key)

        DtApi::Response.new(
          response,
          cached_response: DtApi::Caching.cached_response_or_raise(cache_key, response)
        )
      end
    end

    def wrap_with_response_object(url)
      response = DtApi::Response.new(yield)

      if !response.success?
        DtApi::ErrorReporter.report_error(response, context: url)
      end

      response
    rescue => e
      DtApi::ErrorReporter.report_exception(e, context: url)
      raise
    end

    def base_headers
      headers = { Authorization: "Bearer #{@api_token}" }

      if Rails.env.development?
        headers["X-Consul-Development-Domain"] = Rails.application.secrets.server_name
      end

      { headers: }
    end

    def auth_settings
      additional_settings = {}

      if Rails.env.production?
        username = Rails.application.secrets.dt[:http_username]
        password = Rails.application.secrets.dt[:http_password]

        if username.present? && password.present?
          additional_settings[:basic_auth] = {
            username:,
            password:
          }
        end
      end

      additional_settings
    end
end
