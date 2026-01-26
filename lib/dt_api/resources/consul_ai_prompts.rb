class DtApi::Resources::ConsulAiPrompts
  BASE_PATH = "/consul_ai_prompts".freeze

  def initialize(client)
    @client = client
  end

  def get(codename)
    @client.get_with_auth(
      "#{BASE_PATH}/#{codename}"
    )
  end
end
