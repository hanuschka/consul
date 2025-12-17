module Ai::Settings
  def self.openai_api_key
    ExternalApiKey.openai_api_key
  end

  def self.gemini_api_key
    ExternalApiKey.gemini_api_key
  end

  def self.gpustack_api_key
    ExternalApiKey.gpustack_api_key
  end

  def self.current_llm_model
    if current_llm_provider == "ollama"
      Setting["ai.llm_custom_model"]
    else
      Setting["ai.llm_model"]
    end
  end

  def self.current_llm_provider
    Setting["ai.llm_provider"].presence || "openai"
  end
end
