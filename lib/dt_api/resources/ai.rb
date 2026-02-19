class DtApi::Resources::Ai
  BASE_PATH = "/ai".freeze

  def initialize(client)
    @client = client
  end

  def generate_image(prompt:)
    @client.post(
      BASE_PATH + "/generate_image",
      body: { prompt: }
    )
  end
end
