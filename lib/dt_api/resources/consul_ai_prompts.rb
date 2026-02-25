class DtApi::Resources::ConsulAiPrompts
  BASE_PATH = "/consul_ai_prompts".freeze

  def initialize(client)
    @client = client
  end

  def get(codename, resource_type: nil)
    query = resource_type.present? ? { resource_type: resource_type } : nil

    @client.get(
      "#{BASE_PATH}/#{codename}",
      query: query
    )
  end
end
