class DtApi::Resources::ClientAiAssistantConfigs
  BASE_PATH = "/client_ai_assistant_configs".freeze

  def initialize(client)
    @client = client
  end

  def update(codename:, consul_projekt_phase_id:, params:)
    @client.patch_with_auth(
      BASE_PATH + "/#{codename}",
      body: { consul_projekt_phase_id:, client_ai_assistant_config: params }
    )
  end

  def get(codename:, consul_projekt_phase_id:)
    @client.get_with_auth(BASE_PATH + "/#{codename}", query: { consul_projekt_phase_id: })
  end
end
