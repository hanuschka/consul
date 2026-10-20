class WhatsappApi::Resources::Webhooks
  BASE_PATH = "/v1/configs/webhook".freeze

  def initialize(client)
    @client = client
  end

  def show
    @client.get(BASE_PATH)
  end

  def configure(url:, headers: {})
    @client.post(
      BASE_PATH,
      body: {
        url: url,
        headers: headers
      }.compact_blank
    )
  end
end
