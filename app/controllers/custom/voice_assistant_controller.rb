class VoiceAssistantController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_voice_assistant

  def create_session
    response =
      VoiceAssistant::CreateSessionService.call(
        codename: params[:codename],
        consul_projekt_phase_id: params[:consul_projekt_phase_id]
      )

    render json: response.parsed_response, status: response.code
  end

  def create_session_v2
    response =
      VoiceAssistant::CreateSessionServiceV2.call(
        codename: params[:codename],
        consul_projekt_phase_id: params[:consul_projekt_phase_id]
      )

    render json: response.parsed_response, status: response.code
  end

  def geocode_location_coordinates
    geo_result = Geocoding::LocalSearchService.call(query: params[:location_name]).first

    if geo_result.present?
      render json: {
        coordinates: geo_result.coordinates,
        location_name: geo_result.address
      }
    else
      render json: { error: "Location not found #{params[:location_name]}" }, status: 422
    end
  end

  private

  def authorize_voice_assistant
    authorize! :use, :voice_assistant
  end
end
