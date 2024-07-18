class DtApi
  include HTTParty

  base_uri "#{Rails.application.secrets.dt[:url]}/api"

  def self.connect(**params)
    additional_settings = {}

    if Rails.env.production?
      username = Rails.application.secrets.dt[:http_username]
      password = Rails.application.secrets.dt[:http_password]

      if username.present? && password.present?
        additional_settings[:basic_auth] = {
          username: Rails.application.secrets.dt[:http_username],
          password: Rails.application.secrets.dt[:http_password]
        }
      end
    end

    post(
      "/clients/connect",
      # headers: { "Content-Type" => "application/json" },
      multipart: true,
      body: {
        **params,
        logo: File.open(Rails.root.join("app", "assets", "images", "logo_header.png").to_s)
      },
      **additional_settings
    )
  end
end
