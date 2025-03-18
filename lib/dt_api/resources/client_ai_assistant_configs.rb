class DtApi::Resources::ClientAiAssistantConfigs
  BASE_PATH = "/client_ai_assistant_configs".freeze

  def initialize(client)
    @client = client
  end

  def update(codename:, params:)
    @client.patch_with_auth(
      BASE_PATH + "/#{codename}",
      body: { client_ai_assistant_config: params }
    )
  end

  def get(codename:)
    @client.get_with_auth(BASE_PATH + "/#{codename}")
  end
end
