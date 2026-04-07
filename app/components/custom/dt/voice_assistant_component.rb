class Dt::VoiceAssistantComponent < ApplicationComponent
  delegate :params, to: :helpers

  attr_reader :assistant_codename, :projekt_phase

  def initialize(assistant_codename:, projekt_phase: nil, custom_data: {})
    @assistant_codename = assistant_codename
    @projekt_phase = projekt_phase
    @custom_data = custom_data
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
