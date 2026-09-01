module Ai::RubyLlmFactory
  def self.chat(feature: AiUsageRecord::UNKNOWN_FEATURE, request_timeout: nil, model: nil)
    model ||= Ai::Settings.current_llm_model
    provider = Ai::Settings.current_llm_provider

    context = init
    context.config.request_timeout = request_timeout if request_timeout.present?

    chat = context.chat(
      model: model,
      provider: provider.to_sym,
      assume_model_exists: true
    )

    record_usage_from(chat, feature: feature, provider: provider, model: model)
  end

  def self.chat_with_json_output(output_schema, feature: AiUsageRecord::UNKNOWN_FEATURE,
                                 request_timeout: nil, model: nil)
    chat(feature: feature, request_timeout: request_timeout, model: model)
      .with_schema(output_schema)
  end

  def self.record_usage_from(chat, feature:, provider:, model:)
    chat.after_message do |message|
      AiUsageRecords::RecordChatUsage.call(
        message: message,
        feature: feature,
        provider: provider,
        requested_model: model
      )
    rescue => e
      Rails.logger.error("[AiUsageRecord] Failed to record usage for #{feature}: #{e.message}")
    end

    chat
  end

  def self.init
    case Ai::Settings.current_llm_provider
    when "openai"
      openai_context
    when "anthropic"
      anthropic_context
    when "gemini"
      gemini_context
    when "deepseek"
      deepseek_context
    when "mistral"
      mistral_context
    when "openrouter"
      openrouter_context
    when "perplexity"
      perplexity_context
    when "gpustack"
      gpustack_context
    when "bedrock"
      bedrock_context
    when "vertexai"
      vertex_ai_context
    when "ollama"
      ollama_context
    else
      RubyLLM.context
    end
  end

  def self.openai_context
    RubyLLM.context do |config|
      config.openai_api_key = Ai::Settings.openai_api_key

      if proxy_uri.present?
        config.http_proxy = proxy_uri
      end

      if Setting["ai.llm_api_endpoint"].present?
        config.openai_api_base = Setting["ai.llm_api_endpoint"]
      end
    end
  end

  def self.anthropic_context
    RubyLLM.context do |config|
      config.anthropic_api_key = Ai::Settings.anthropic_api_key

      if proxy_uri.present?
        config.http_proxy = proxy_uri
      end
    end
  end

  def self.gemini_context
    RubyLLM.context do |config|
      config.gemini_api_key = Ai::Settings.gemini_api_key

      if proxy_uri.present?
        config.http_proxy = proxy_uri
      end

      if Setting["ai.llm_api_endpoint"].present?
        config.gemini_api_base = Setting["ai.llm_api_endpoint"]
      end
    end
  end

  def self.deepseek_context
    RubyLLM.context do |config|
      config.deepseek_api_key = Ai::Settings.deepseek_api_key

      if proxy_uri.present?
        config.http_proxy = proxy_uri
      end
    end
  end

  def self.mistral_context
    RubyLLM.context do |config|
      config.mistral_api_key = Ai::Settings.mistral_api_key

      if proxy_uri.present?
        config.http_proxy = proxy_uri
      end
    end
  end

  def self.openrouter_context
    RubyLLM.context do |config|
      config.openrouter_api_key = Ai::Settings.openrouter_api_key

      if proxy_uri.present?
        config.http_proxy = proxy_uri
      end
    end
  end

  def self.perplexity_context
    RubyLLM.context do |config|
      config.perplexity_api_key = Ai::Settings.perplexity_api_key

      if proxy_uri.present?
        config.http_proxy = proxy_uri
      end
    end
  end

  def self.gpustack_context
    RubyLLM.context do |config|
      config.gpustack_api_key = Ai::Settings.gpustack_api_key

      if proxy_uri.present?
        config.http_proxy = proxy_uri
      end

      if Setting["ai.llm_api_endpoint"].present?
        config.gpustack_api_base = Setting["ai.llm_api_endpoint"]
      end
    end
  end

  def self.bedrock_context
    RubyLLM.context do |config|
      config.aws_access_key_id = Ai::Settings.bedrock_access_key_id
      config.aws_secret_access_key = Ai::Settings.bedrock_secret_access_key

      if Ai::Settings.bedrock_region.present?
        config.aws_region = Ai::Settings.bedrock_region
      end

      if proxy_uri.present?
        config.http_proxy = proxy_uri
      end
    end
  end

  def self.vertex_ai_context
    RubyLLM.context do |config|
      config.vertex_project = Ai::Settings.vertex_ai_project

      if proxy_uri.present?
        config.http_proxy = proxy_uri
      end

      if Ai::Settings.vertex_ai_credentials.present?
        config.vertex_credentials = JSON.parse(Ai::Settings.vertex_ai_credentials)
      end
    end
  end

  def self.ollama_context
    RubyLLM.context do |config|
      config.ollama_api_base = Setting["ai.llm_api_endpoint"].presence || "http://127.0.0.1:11434/v1"

      if proxy_uri.present?
        config.http_proxy = proxy_uri
      end
    end
  end

  def self.proxy_uri
    @proxy_uri ||= begin
      proxy_config = Rails.application.secrets.web_server_proxy

      return nil if proxy_config.blank?
      return nil if proxy_config[:address].blank?

      address = proxy_config[:address]
      port = proxy_config[:port]
      username = proxy_config[:username]
      password = proxy_config[:password]

      uri =
        if username.present?
          "http://#{username}:#{password}@#{address}:#{port}"
        else
          "http://#{address}:#{port}"
        end

      Rails.logger.debug "[Ai::RubyLlmFactory] Using proxy: #{uri}"

      uri
    end
  end
end
