module Ai::Settings
  def self.ai_available?
    case current_llm_provider
    when "openai"
      openai_api_key.present?
    when "gemini"
      gemini_api_key.present?
    when "gpustack"
      gpustack_api_key.present?
    when "ollama"
      true
    else
      false
    end
  end

  def self.llm_model_set?
    current_llm_model.present?
  end

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
    RubyLLM.models.refresh!

    if current_llm_provider == "ollama"
      Setting["ai.llm_custom_model"]
    else
      if current_llm_provider == "openai" && Setting["ai.llm_model"].blank?
        "gpt-5.2"
      else
        Setting["ai.llm_model"]
      end
    end
  end

  def self.current_llm_provider
    Setting["ai.llm_provider"].presence || "openai"
  end
end
