class Dt::VoiceAssistantComponent < ApplicationComponent
  delegate :params, to: :helpers

  attr_reader :assistant_codename, :projekt_phase, :version

  def initialize(assistant_codename:, projekt_phase: nil, custom_data: {}, version: :v2)
    @assistant_codename = assistant_codename
    @projekt_phase = projekt_phase
    @custom_data = custom_data
    @version = version
  end

  def create_session_url
    if version == :v1
      helpers.voice_assistant_create_session_path
    else
      helpers.voice_assistant_create_session_v2_path
    end
  end

  def render?
    Ai::Settings.ai_available?
  end

  def language
    if Rails.env.development?
      :en
    else
      :de
    end
  end

  def assistant_initial_data
    @custom_data.to_json
  end
end
