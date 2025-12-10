module Ai::RubyLlmFactory
  def self.chat
    init.chat(model: current_llm_model)
  end

  def self.chat_with_json_output(output_schema)
    chat
      .with_schema(output_schema)
  end

  def self.init
    if current_llm_provider == 'openai'
      openai_context
    elsif current_llm_provider == "ollama"
      ollama_context
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
      config.ollama_api_base = "http://127.0.0.1:11434/v1"
    end
  end

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
    Setting["ai.llm_provider"].presence || "openai"
  end
end
