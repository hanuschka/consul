module Ai::Settings
  def self.openai_api_key
    ExternalApiKey.openai_token
  end

  def self.current_llm_model
    if current_llm_provider == "ollama"
      Setting["ai.llm_custom_model"]
    else
      Setting["ai.llm_model"]
    end
  end

  def self.current_llm_provider
    Setting["ai.llm_provider"]
  end
end
