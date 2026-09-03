module Ai::Settings
  DEFAULT_GPT_MODEL = "gpt-5.6-sol"

  # Cheaper tiers of the same generation, for calls that classify pre-filtered
  # candidates rather than generate prose. Read them through fast_model and
  # ultrafast_model, never directly: the names exist only on OpenAI itself.
  FAST_MODEL = "gpt-5.6-terra".freeze
  ULTRAFAST_MODEL = "gpt-5.6-luna".freeze
  private_constant :FAST_MODEL, :ULTRAFAST_MODEL

  def self.feature_enabled?
    Rails.application.secrets.dig(:ai, :enabled) == true
  end

  def self.voice_assistant_allowed?
    feature_enabled?
  end

  def self.ai_available?
    return false unless feature_enabled?

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
    when "vertexai"
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
    custom_model = Setting["ai.llm_custom_model"]
    custom_endpoint = Setting["ai.llm_api_endpoint"]

    if custom_model.present? && (current_llm_provider == "ollama" || custom_endpoint.present?)
      return custom_model
    end

    if current_llm_provider == "openai"
      DEFAULT_GPT_MODEL
    else
      Setting["ai.llm_model"]
    end
  end

  def self.current_llm_provider
    Setting["ai.llm_provider"].presence || "openai"
  end

  def self.fast_model
    openai_tier_model(FAST_MODEL)
  end

  def self.ultrafast_model
    openai_tier_model(ULTRAFAST_MODEL)
  end

  # An instance pointed at another provider, or at an OpenAI-compatible endpoint
  # serving its own catalogue, gets the model it configured instead.
  def self.openai_tier_model(model)
    return model if standard_openai?

    current_llm_model
  end

  # Whether the provider is OpenAI at all, custom endpoint or not. Asked apart
  # from standard_openai?, which is the narrower question of whether the model
  # *catalogue* is OpenAI's own: the tier model names below exist only on OpenAI
  # itself, while the chat-completions request schema is served by anything
  # configured under this provider.
  def self.openai?
    current_llm_provider == "openai"
  end

  def self.standard_openai?
    openai? && Setting["ai.llm_api_endpoint"].blank?
  end
end
