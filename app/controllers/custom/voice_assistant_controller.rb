class VoiceAssistantController < ActionController::Base
  skip_authorization_check

  def create_session
    dt_api = DtApi::Client.new
    dt_api.voice_assistant.create_session(
      session_uuid: params[:session_uuid],
      codename: params[:codename],
      consul_projekt_phase_id: params[:consul_projekt_phase_id]
    )
  end
end
