class Admin::FeaturesService < ApplicationService
  def call
    {
      ai: ai_feature
    }
  end

  private

  def ai_feature
    {
      enabled:             Ai::Settings.ai_available?,
      custom_client_token: custom_client_token?,
      ai_model:            Ai::Settings.current_llm_model,
      ai_provider:         Ai::Settings.current_llm_provider
    }
  end

  def custom_client_token?
    case Ai::Settings.current_llm_provider
    when "bedrock"
      stored_value?("bedrock", "access_key_id")
    when "vertex_ai"
      stored_value?("vertex_ai", "project")
    when "ollama"
      false
    else
      stored_value?(Ai::Settings.current_llm_provider, "api_key")
    end
  end

  def stored_value?(service, name)
    ExternalApiKey.find_by(service: service, name: name)&.value.present?
  end
end
