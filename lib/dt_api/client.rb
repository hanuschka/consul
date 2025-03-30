class DtApi::Client
  include HTTParty

  base_uri "#{Rails.application.secrets.dt[:url]}/api"

  def initialize(api_token = nil)
    @api_token = api_token || ApiClient&.dt&.service_api_token
  end

  def ai_assistant_configs
    @projekts ||= DtApi::Resources::ClientAiAssistantConfigs.new(
      self
    )
  end

  def get_with_auth(url, query: nil)
    self.class.get(
      url,
      query: query,
      **base_headers,
      **auth_settings,
    )
  end

  def post_with_auth(url, body:, multipart: false)
    self.class.post(
      url,
      multipart: multipart,
      **base_headers,
      **auth_settings,
      body: body
    )
  end

  def patch_with_auth(url, body:, multipart: false)
    self.class.patch(
      url,
      multipart: multipart,
      **base_headers,
      **auth_settings,
      body: body
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
      {}
    end
  end

  def auth_settings
    additional_settings = {}

    if Rails.env.production?
      username = Rails.application.secrets.dt[:http_username]
      password = Rails.application.secrets.dt[:http_password]

      if username.present? && password.present?
        additional_settings[:basic_auth] = {
          username: username,
          password: password
        }
      end
    end

    additional_settings
  end
end
