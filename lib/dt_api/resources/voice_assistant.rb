class DtApi::Resources::VoiceAssistant
  BASE_PATH = "/voice_assistant".freeze

  def initialize(client)
    @client = client
  end

  def create_session(session_uuid:, codename:, consul_projekt_phase_id:)
    @client.post_with_auth(
      BASE_PATH + "/create_session",
      body: {
        session_uuid: session_uuid,
        codename: codename,
        consul_projekt_phase_id: consul_projekt_phase_id
      }
    )
  end
end
