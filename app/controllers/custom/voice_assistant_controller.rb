class VoiceAssistantController < ActionController::Base
  skip_authorization_check

  DEFICIENCY_REPORT_CODENAME = "deficiency_report_voice_assistant".freeze

  def create_session
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


    response =
      dt_api.voice_assistant.create_session(
        codename: params[:codename],
        consul_projekt_phase_id: params[:consul_projekt_phase_id],
        data: data
      )

    render json: response.parsed_response, status: response.code
  end

  def geocode_location_coordinates
    geo_result = Geocoder.search(params[:location_name]).first

    if geo_result.present?
      render json: {
        coordinates: geo_result.coordinates,
        location_name: geo_result.address
      }
    else
      render json: { error: "Location not found #{params[:location_name]}" }, status: 422
    end
  end

  def generate_image
    if params[:codename] == DEFICIENCY_REPORT_CODENAME
      render json: { error: "Image generation not available" }, status: 403
      return
    end

    response = dt_api.voice_assistant.generate_image(prompt: params[:prompt])
    render json: response.parsed_response, status: response.code
  end

  private

  def dt_api
    DtApi::Client.new
  end
end
