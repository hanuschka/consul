class VoiceAssistantController < ApplicationController
  before_action :authenticate_user!
  before_action :authorize_voice_assistant

  DEFICIENCY_REPORT_CODENAME = "deficiency_report_voice_assistant".freeze

  def create_session
    response =
      VoiceAssistant::CreateSessionService.call(
        codename: params[:codename],
        consul_projekt_phase_id: params[:consul_projekt_phase_id]
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

    unless response.success?
      Sentry.capture_message(
        "VoiceAssistant generate_image failed",
        level: "error",
        extra: {
          status: response.code,
          body: response.parsed_response,
          codename: params[:codename]
        }
      )
    end

    render json: response.parsed_response, status: response.code
  end

  private

  def authorize_voice_assistant
    authorize! :use, :voice_assistant
  end

  def dt_api
    DtApi::Client.new
  end
end
