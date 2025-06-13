class VoiceAssistantController < ActionController::Base
  skip_authorization_check

  def create_session
    dt_api = DtApi::Client.new
    projekt_phase = ProjektPhase.find(params[:consul_projekt_phase_id])
    projekt = projekt_phase.projekt

    data = {
      projekt: {
        title: projekt.title,
      },
      projekt_phase: {
        labels: projekt_phase.projekt_labels.as_json(only: [:id, :name]),
        sentiments: projekt_phase.sentiments.as_json(only: [:id, :name, :color])
      }
    }
    dt_api.voice_assistant.create_session(
      session_uuid: params[:session_uuid],
      codename: params[:codename],
      consul_projekt_phase_id: params[:consul_projekt_phase_id],
      data: data
    )
  end
end
