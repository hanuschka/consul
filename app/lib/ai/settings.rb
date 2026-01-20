module Ai::Settings
  def self.ai_available?
    return false unless Rails.application.secrets.dig(:ai, :enabled) == true

    case current_llm_provider
    when "openai"
      openai_api_key.present?
    when "anthropic"
      anthropic_api_key.present?
    when "gemini"
      gemini_api_key.present?
    when "deepseek"
      deepseek_api_key.present?
    when "mistral"
      mistral_api_key.present?
    when "openrouter"
      openrouter_api_key.present?
    when "perplexity"
      perplexity_api_key.present?
    when "gpustack"
      gpustack_api_key.present?
    when "bedrock"
      bedrock_access_key_id.present? && bedrock_secret_access_key.present?
    when "vertex_ai"
      vertex_ai_project.present?
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

  def self.anthropic_api_key
    ExternalApiKey.anthropic_api_key
  end

  def self.gemini_api_key
    ExternalApiKey.gemini_api_key
  end

  def self.deepseek_api_key
    ExternalApiKey.deepseek_api_key
  end

  def self.mistral_api_key
    ExternalApiKey.mistral_api_key
  end

  def self.openrouter_api_key
    ExternalApiKey.openrouter_api_key
  end

  def self.perplexity_api_key
    ExternalApiKey.perplexity_api_key
  end

  def self.gpustack_api_key
    ExternalApiKey.gpustack_api_key
  end

  def self.bedrock_access_key_id
    ExternalApiKey.bedrock_access_key_id
  end

  def self.bedrock_secret_access_key
    ExternalApiKey.bedrock_secret_access_key
  end

  def self.bedrock_region
    ExternalApiKey.bedrock_region
  end

  def self.vertex_ai_project
    ExternalApiKey.vertex_ai_project
  end

  def self.vertex_ai_credentials
    ExternalApiKey.vertex_ai_credentials
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
