class Dt::VoiceAssistant::PreviewListComponent < ApplicationComponent
  attr_reader :projekt_phase_id, :codename

  def initialize(variant: :grid, projekt_phase_id: nil, codename: "proposal_voice_assistant")
    @variant = variant
    @projekt_phase_id = projekt_phase_id
    @codename = codename
  end

  def self.enabled?
    Rails.env.development? || Rails.env.staging?
  end

  def render?
    self.class.enabled?
  end

  def list_modifier
    return "-vertical" if @variant == :vertical

    ""
  end

  def create_session_url
    helpers.voice_assistant_create_session_v2_path
  end
end
