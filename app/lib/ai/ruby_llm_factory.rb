module Ai::RubyLlmFactory
  def self.chat
    init.chat(model: current_llm_model)
  end

  def self.chat_with_json_output(output_schema)
    chat.with_schema(output_schema)
  end

  def self.init
    case Ai::Settings.current_llm_provider
    when "openai"
      openai_context
    when "ollama"
      ollama_context
    when "gemini"
      gemini_context
    when "gpustack"
      gemini_context
    else
      RubyLLM
    end
  end

  def self.openai_context
    RubyLLM.context do |config|
      config.openai_api_key = openai_api_key

      if Setting["ai.llm_api_endpoint"].present?
        config.openai_api_base = Setting["ai.llm_api_endpoint"]
      end
    end
  end

  def self.ollama_context
    RubyLLM.context do |config|
      config.ollama_api_base = Setting["ai.llm_api_endpoint"].presence || "http://127.0.0.1:11434/v1"
    end
  end

  def self.gemini_context
    RubyLLM.context do |config|
      config.gemini_api_key = Ai::Settings.gemini_api_key

      if Setting["ai.llm_api_endpoint"].present?
        config.gemini_api_base = Setting["ai.llm_api_endpoint"]
      end
    end
  end

  def self.gpustack_context
    RubyLLM.context do |config|
      config.gpustack_api_key = Ai::Settings.gpustack_api_key

      if Setting["ai.llm_api_endpoint"].present?
        config.gpustack_api_base = Setting["ai.llm_api_endpoint"]
      end
    end
  end

  def self.llm_model_set?
    current_llm_model.present?
  end

  def self.openai_api_key
    ExternalApiKey.openai_api_key
  end

  def self.current_llm_model
    RubyLLM.models.refresh!

    if current_llm_provider == "ollama"
      Setting["ai.llm_custom_model"]
    else
      if current_llm_provider == "openai" && Setting["ai.llm_model"].blank?
        # "gpt-5-nano"
        # "gpt-5.1-codex"
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
