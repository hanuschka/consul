class VoiceAssistantController < ActionController::Base
  skip_authorization_check

  def create_session
    dt_api = DtApi::Client.new

    data = {}

    if params[:consul_projekt_phase_id].present?
      projekt_phase = ProjektPhase.find(params[:consul_projekt_phase_id])
      projekt = projekt_phase.projekt

      data.merge!({
        projekt: {
          title: projekt.title,
        },
        projekt_phase: {
          labels: projekt_phase.projekt_labels.as_json(only: [:id, :name]),
          sentiments: projekt_phase.sentiments.as_json(only: [:id, :name, :color])
        }
      })
    end

    if params[:codename] == "budget_proposal_voice_assistant"
      implementation_performers =
        Budget::Investment.implementation_performers.map { |ip|
          [ t("activerecord.attributes.budget/investment.implementation_performers.#{ip[0]}"), ip[0]]
        }

      data.merge!({
        implementation_performers: implementation_performers
      })
    end

    if params[:codename] == "deficiency_report_voice_assistant"
      data.merge!({
        categories: DeficiencyReport::Category.all.as_json(only: [:id, :name])
      })
    end


    dt_api.voice_assistant.create_session(
      session_uuid: params[:session_uuid],
      codename: params[:codename],
      consul_projekt_phase_id: params[:consul_projekt_phase_id],
      data: data
    )
  end
end
