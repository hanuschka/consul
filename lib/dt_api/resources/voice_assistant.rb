class DtApi::Resources::VoiceAssistant
  BASE_PATH = "/voice_assistant".freeze

  def initialize(client)
    @client = client
  end

  def create_session(codename:, consul_projekt_phase_id:, data:)
    @client.post_with_auth(
      BASE_PATH + "/create_session",
      body: {
        codename:,
        consul_projekt_phase_id:,
        data:
      }
    )
  end
end
