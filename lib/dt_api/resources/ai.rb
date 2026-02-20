class DtApi::Resources::Ai
  BASE_PATH = "/ai".freeze

  def initialize(client)
    @client = client
  end

  def generate_image(prompt:, aspect_ratio: nil)
    body = { prompt: }
    body[:aspect_ratio] = aspect_ratio if aspect_ratio.present?

    @client.post(BASE_PATH + "/generate_image", body:)
  end
end
