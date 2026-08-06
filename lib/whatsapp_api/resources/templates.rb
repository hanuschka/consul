class WhatsappApi::Resources::Templates
  BASE_PATH = "/v1/configs/templates".freeze
  DEFAULT_CATEGORY = "UTILITY".freeze

  def initialize(client)
    @client = client
  end

  def index
    @client.get(BASE_PATH)
  end

  def create(name:, language:, body:, example_variables: [], category: DEFAULT_CATEGORY)
    @client.post(
      BASE_PATH,
      body: {
        name: name,
        language: language,
        category: category,
        components: [body_component(body, example_variables)]
      }
    )
  end

  private

    def body_component(body, example_variables)
      component = { type: "BODY", text: body }

      return component if example_variables.blank?

      component.merge(example: { body_text: [example_variables] })
    end
end
