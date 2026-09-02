class DtApi::Resources::Ai
  BASE_PATH = "/ai".freeze

  # Stands in for the provider when the DT deployment is older than the
  # response keys below and names nothing: the service this app called is then
  # the most precise thing it can attest.
  PROVIDER_NAME = "Demokratie Today AI".freeze

  def self.reported_provider(response_body)
    response_body["ai_provider"].presence || PROVIDER_NAME
  end

  def self.reported_model(response_body)
    response_body["ai_model"].presence
  end

  def initialize(client)
    @client = client
  end

  def generate_image(prompt:, aspect_ratio: nil)
    body = { prompt: }
    body[:aspect_ratio] = aspect_ratio if aspect_ratio.present?

    @client.post(BASE_PATH + "/generate_image", body:)
  end
end
