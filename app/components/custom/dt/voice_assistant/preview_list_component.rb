class Dt::VoiceAssistant::PreviewListComponent < ApplicationComponent
  attr_reader :projekt_phase_id, :codename

  def initialize(variant: :grid, projekt_phase_id: nil, codename: "proposal_voice_assistant")
    @variant = variant
    @projekt_phase_id = projekt_phase_id
    @codename = codename
  end

  def render?
    helpers.params[:designs].to_s == "true"
  end

  def list_modifier
    return "-vertical" if @variant == :vertical

    ""
  end

  def create_session_url
    helpers.voice_assistant_create_session_v2_path
  end

  def geocode_url
    helpers.voice_assistant_geocode_location_coordinates_path
  end

  def generate_image_url
    helpers.ai_generate_image_path
  end

  def aspect_ratio
    "16:9"
  end
end
