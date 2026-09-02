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
        logo: File.open(Dt.logo_path.to_s)
      }
    )
  end
end
