module Ai::Settings
  DEFAULT_GPT_MODEL = "gpt-5.6-sol"

  # Cheaper tiers of the same generation, for calls that classify pre-filtered
  # candidates rather than generate prose. Read them through fast_model and
  # ultrafast_model, never directly: the names exist only on OpenAI itself.
  FAST_MODEL = "gpt-5.6-terra".freeze
  ULTRAFAST_MODEL = "gpt-5.6-luna".freeze
  private_constant :FAST_MODEL, :ULTRAFAST_MODEL

  # A temporary control for comparing the three tiers against each other on the
  # staging system, read by the WhatsApp chat services and nothing else. When
  # the comparison has been made, the tier that won is named in those services
  # directly and all of this comes out again.
  WHATSAPP_MODEL_TIER_SETTING_KEY = "ai.whatsapp_model_tier".freeze
  WHATSAPP_TIER_BIG = "big".freeze
  WHATSAPP_TIER_FAST = "fast".freeze
  WHATSAPP_TIER_ULTRAFAST = "ultrafast".freeze
  WHATSAPP_MODEL_TIERS = [
    WHATSAPP_TIER_BIG, WHATSAPP_TIER_FAST, WHATSAPP_TIER_ULTRAFAST
  ].freeze

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

  # The three tiers are three separate models only on OpenAI's own catalogue,
  # so anywhere else the choice is neither offered nor read: a stored value
  # survives a provider switch without taking effect while it is switched.
  def self.whatsapp_model_tier
    return WHATSAPP_TIER_FAST if !standard_openai?

    tier = Setting[WHATSAPP_MODEL_TIER_SETTING_KEY].to_s

    return tier if WHATSAPP_MODEL_TIERS.include?(tier)

    WHATSAPP_TIER_FAST
  end

  def self.whatsapp_model
    whatsapp_tier_model(whatsapp_model_tier)
  end

  # Asked per tier rather than only for the selected one so the admin dropdown
  # can name the model id each option would send.
  def self.whatsapp_tier_model(tier)
    case tier
    when WHATSAPP_TIER_BIG
      current_llm_model
    when WHATSAPP_TIER_ULTRAFAST
      ultrafast_model
    else
      fast_model
    end
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
