class DtApi::Resources::Clients
  BASE_PATH = "/clients".freeze

  def initialize(client)
    @client = client
  end

  def connect(**params)
    @client.post(
      "#{BASE_PATH}/connect",
      multipart: true,
      body: {
        **params,
        logo: File.open(Rails.root.join("app", "assets", "images", "logo_header.png").to_s)
      }
    )
  end
end
