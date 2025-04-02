class DtApi
  include HTTParty

  base_uri "#{Dt.url}/api"

  def initialize(api_token = nil)
    @api_token = api_token
  end

  def connect(**params)
    post_with_auth(
      "/clients/connect",
      multipart: true,
      body: {
        **params,
        logo: File.open(Rails.root.join("app", "assets", "images", "logo_header.png").to_s)
      }
    )
  end

  def projekt_updated(projekt_id, serialized_projekt)
    patch_with_auth(
      "/projekts/#{projekt_id}/projekt_updated",
      body: { projekt: serialized_projekt }
    )
  end

  def projekt_destroyed(projekt_id)
    delete_with_auth(
      "/projekts/#{projekt_id}/projekt_destroyed"
    )
  end

  def update_projekt_manager_permission(projekt_id, user_id, allowed_to_manage)
    patch_with_auth(
      "/projekts/#{projekt_id}/update_projekt_manager_permission",
      body: {
        user_id: user_id,
        allowed_to_manage: allowed_to_manage
      }
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
