module Ai::EvaluationContext
  SETTING_KEY = "ai.evaluation_context".freeze

  LABEL = "Background about the municipality running this platform:".freeze

  def self.prepend_to(instructions, record)
    text = landing_page_for(record)&.landing_ai_context.presence || Setting[SETTING_KEY].presence
    return instructions if text.blank?

    "#{LABEL}\n#{text.strip}\n\n#{instructions}"
  end

  def self.landing_page_for(record)
    case record
    when ::Projekt
      record.landing_page
    when ::ProjektPhase, ::Poll
      record.projekt&.landing_page
    end
  end
end
