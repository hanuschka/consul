module Ai::RubyLlmFactory
  # Chat Completions refuses function tools from the GPT-5.5 generation onward
  # unless reasoning is explicitly switched off, and a chat that never names an
  # effort gets the model's own default rather than nothing — so on that
  # transport the tools have to travel with the one value that makes them legal.
  TOOL_REASONING_EFFORT = "none".freeze

  def self.chat(feature: AiUsageRecord::UNKNOWN_FEATURE)
    build_chat(init, feature: feature)
  end

  def self.chat_with_request_timeout(seconds, feature: AiUsageRecord::UNKNOWN_FEATURE, gpt_model: nil)
    build_chat(context_with_request_timeout(seconds), feature: feature, gpt_model: gpt_model)
  end

  def self.chat_with_json_output(output_schema, feature: AiUsageRecord::UNKNOWN_FEATURE,
                                 request_timeout: nil, gpt_model: nil)
    base =
      if request_timeout.present?
        chat_with_request_timeout(request_timeout, feature: feature, gpt_model: gpt_model)
      else
        build_chat(init, feature: feature, gpt_model: gpt_model)
      end

    base.with_schema(output_schema)
  end

  # The cheap model on a bounded clock, for the short judgements made while
  # someone is waiting on the other end of a chat — routing a message, ranking
  # a handful of titles, rewording one line. Three callers asked for exactly
  # this pairing by hand before it had a name.
  def self.fast_chat(timeout_seconds, feature: AiUsageRecord::UNKNOWN_FEATURE)
    chat_with_request_timeout(
      timeout_seconds,
      feature: feature,
      gpt_model: Ai::Settings.fast_model
    )
  end

  # The place tools get attached, rather than each caller reaching for
  # with_tools: the effort above is a property of asking OpenAI for tools at
  # all, and a caller that forgets it only finds out from a 400 in production.
  # Every other provider rejects the key, so they keep the chat unchanged.
  def self.attach_tools(chat, *tools)
    chat.with_tools(*tools)

    return chat if Ai::Settings.current_llm_provider != "openai"

    chat.with_thinking(effort: TOOL_REASONING_EFFORT)
  end

  # Embeddings are a provider call like any other, so they are wired here too
  # rather than in a caller: only openai is configured with an embedding model,
  # and embeddable? is what retrieval checks before relying on vectors.
  def self.embed(input, model:, dimensions:, feature: AiUsageRecord::UNKNOWN_FEATURE)
    provider = Ai::Settings.current_llm_provider

    embedding = init.embed(
      input,
      model: model,
      provider: provider.to_sym,
      assume_model_exists: true,
      dimensions: dimensions
    )

    AiUsageRecords::RecordEmbeddingUsage.call(
      embedding: embedding,
      feature: feature,
      provider: provider,
      requested_model: model
    )

    embedding
  end

  def self.embeddable?
    Ai::Settings.current_llm_provider == "openai"
  end

  def self.build_chat(context, feature:, gpt_model: nil)
    model = model_for(gpt_model)
    provider = Ai::Settings.current_llm_provider

    chat = context.chat(
      model: model,
      provider: provider.to_sym,
      assume_model_exists: true
    )

    record_usage_from(chat, feature: feature, provider: provider, model: model)
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

  # A model id named for one provider means nothing to another, and an
  # OpenAI-compatible endpoint serves its own catalogue under its own names, so
  # a caller's preference holds only on OpenAI itself. Everywhere else the
  # configured model is the only one the instance is known to be able to reach.
  def self.model_for(gpt_model)
    return Ai::Settings.current_llm_model if gpt_model.blank?
    return Ai::Settings.current_llm_model if !Ai::Settings.standard_openai?

    gpt_model
  end

  # An unrecognised provider leaves init returning the RubyLLM module itself,
  # whose config is the global one — writing a timeout there would shorten it
  # for every other caller in the process.
  def self.context_with_request_timeout(seconds)
    context = init

    return context if !context.is_a?(RubyLLM::Context)

    context.config.request_timeout = seconds

    context
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
