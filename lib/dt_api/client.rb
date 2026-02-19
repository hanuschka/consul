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

  def initialize(api_token = nil)
    @api_token = api_token || InternalApiClient&.dt&.service_api_token
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
    @projekts ||= DtApi::Resources::ClientAiAssistantConfigs.new(
      self
    )
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

  def get_with_auth(url, query: nil)
    self.class.get(
      url,
      query:,
      **base_headers,
      **auth_settings,
    )
  end

  def post_with_auth(url, body:, multipart: false)
    self.class.post(
      url,
      multipart:,
      **base_headers,
      **auth_settings,
      body:
    )
  end

  def patch_with_auth(url, body:, multipart: false)
    self.class.patch(
      url,
      multipart:,
      **base_headers,
      **auth_settings,
      body:
    )
  end

  def delete_with_auth(url)
    self.class.delete(
      url,
      **base_headers,
      **auth_settings
    )
  end

  def base_headers
    if Rails.env.development?
      {
        headers: {
          "X-Consul-Development-Domain" => Rails.application.secrets.server_name,
          Authorization: "Bearer #{@api_token}"
        }
      }
    else
      {
        headers: {
          Authorization: "Bearer #{@api_token}"
        }
      }
    end
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
