if Rails.application.secrets.ai&.fetch(:enabled, false) == true
  require 'ruby_llm'

  RubyLLM.configure do |config|
    config.openai_api_key = Rails.application.secrets.ai&.fetch(:openai_api_key, nil)
  end
end
