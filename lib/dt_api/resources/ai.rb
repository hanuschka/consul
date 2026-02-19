class DtApi::Resources::Ai
  BASE_PATH = "/ai".freeze

  def initialize(client)
    @client = client
  end

  def generate_image(prompt:)
    @client.post_with_auth(
      BASE_PATH + "/generate_image",
      body: { prompt: }
    )
  end
end
