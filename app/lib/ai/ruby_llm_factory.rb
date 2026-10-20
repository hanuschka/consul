module Ai::RubyLlmFactory
  # ruby_llm requires a Vertex AI location and the settings offer none. The global
  # endpoint serves the Gemini models without pinning a region.
  VERTEX_AI_LOCATION = "global".freeze

  EXPLICIT_CACHING_PROVIDERS = %w[anthropic bedrock].freeze

  CONVERSATION_FEATURES = %w[whatsapp.assistant].freeze

  REPEATED_PREFIX_FEATURES = %w[
    whatsapp.assistant
    whatsapp.bot_copy
    similar_contributions.find_for_additional_projekts
    similar_contributions.find_for_phase
    similar_contributions.find_for_projekt
  ].freeze

  # The one builder. A chat is pinned to the model its profile chose and carries
  # the tools it was asked for in the same call, so the model it talks to and the
  # effort those tools are named with are always answers from the same profile —
  # a caller holding the two apart is a caller that can let them drift.
  def self.chat_for(
    profile, feature: AiUsageRecord::UNKNOWN_FEATURE, request_timeout: nil, tools: []
  )
    chat = build_chat(
      context_for(request_timeout), feature: feature, gpt_model: profile.model
    )

    return chat if tools.blank?

    attach_tools(chat, tools, profile)
  end

  def self.chat(feature: AiUsageRecord::UNKNOWN_FEATURE)
    chat_for(::Ai::ModelProfile.default, feature: feature)
  end

  def self.chat_with_json_output(
    output_schema, feature: AiUsageRecord::UNKNOWN_FEATURE, request_timeout: nil
  )
    chat_for(::Ai::ModelProfile.default, feature: feature, request_timeout: request_timeout)
      .with_schema(output_schema)
  end

  def self.context_for(request_timeout)
    return init if request_timeout.blank?

    context_with_request_timeout(request_timeout)
  end

  # Kept apart from chat_for only because the warning below belongs next to the
  # attachment rather than in the middle of building a chat: whether an effort
  # may be named alongside tools is the profile's answer, not the caller's, and
  # a caller that got it wrong only found out from a 400 in production.
  def self.attach_tools(chat, tools, profile)
    warn_unsupported_tools(profile)

    chat.with_tools(*tools)

    return chat if profile.reasoning_effort.blank?

    chat.with_thinking(effort: profile.reasoning_effort)
  end

  # Logged rather than enforced: the registry is a snapshot shipped with the
  # gem, so a model missing from it is far likelier to be newer than the
  # snapshot than to be one that cannot call tools at all.
  def self.warn_unsupported_tools(profile)
    return if profile.tools_supported?

    Rails.logger.warn(
      "[Ai::RubyLlmFactory] #{profile.model} is listed without function " \
      "calling; attaching tools anyway"
    )
  end

  # Embeddings are a provider call like any other, so they are wired here too
  # rather than in a caller: only openai is configured with an embedding model,
  # and embeddable? is what retrieval checks before relying on vectors.
  def self.embed(input, model:, dimensions:, feature: AiUsageRecord::UNKNOWN_FEATURE)
    provider = Ai::Settings.current_llm_provider
    context = attribute_usage(
      init, feature: feature, provider: provider, requested_model: model
    )

    context.embed(
      input,
      model: model,
      provider: provider.to_sym,
      assume_model_exists: true,
      dimensions: dimensions
    )
  end

  def self.embeddable?
    Ai::Settings.current_llm_provider == "openai"
  end

  def self.build_chat(context, feature:, gpt_model: nil)
    model = model_for(gpt_model)
    provider = Ai::Settings.current_llm_provider

    chat =
      attribute_usage(context, feature: feature, provider: provider, requested_model: model)
        .chat(
          model: model,
          provider: provider.to_sym,
          protocol: protocol_for_endpoint,
          assume_model_exists: true
        )

    apply_prompt_caching(chat, feature)
  end

  # ruby_llm speaks OpenAI's Responses API by default, and so does this app on
  # OpenAI itself. An OpenAI-compatible endpoint serves the chat-completions schema
  # and seldom anything else, so it keeps that one. Nil leaves the choice to the
  # provider, which is every other case.
  def self.protocol_for_endpoint
    return if !Ai::Settings.openai?
    return if Ai::Settings.standard_openai?

    :chat_completions
  end

  # Usage is booked off ruby_llm's per-attempt usage events rather than off the
  # messages a chat receives: a request that failed or was retried produced no
  # message and was still sent, often billed. Every call made through the
  # context — chat, embedding, transcription — reports to the instrumenter.
  #
  # Each context is built for one call, so the instrumenter set here never
  # leaks to another feature; the guard is the same one the timeout needs.
  def self.attribute_usage(context, feature:, provider:, requested_model:)
    return context if !context.is_a?(RubyLLM::Context)

    context.config.instrumenter = ::Ai::UsageInstrumenter.new(
      feature: feature,
      provider: provider,
      requested_model: requested_model,
      delegate: context.config.instrumenter
    )

    context
  end

  # On OpenAI's own API caching is automatic and free; a prompt_cache_key per
  # feature only routes requests sharing a prefix to the same cache, raising the
  # hit rate. The key is withheld from an OpenAI-compatible endpoint, which may
  # refuse a parameter it does not know, and from the unknown feature, which
  # would pool unrelated prompts under one key.
  #
  # Anthropic and Bedrock charge a premium for every cache write, so caching
  # there is opt-in: automatic caching only for a conversation, whose next
  # request repeats everything the last one sent, and a boundary after the
  # instructions (cache_prefix) only for features whose instructions repeat.
  def self.apply_prompt_caching(chat, feature)
    cache_key = prompt_cache_key(feature)

    if Ai::Settings.standard_openai? && cache_key.present?
      chat.with_caching(key: cache_key)
    elsif explicit_caching_provider? && CONVERSATION_FEATURES.include?(feature)
      chat.with_caching
    else
      chat
    end
  end

  # Read by OpenaiApi::Responses as well, so both transports key a feature's
  # requests the same way.
  def self.prompt_cache_key(feature)
    if AiUsageRecord.known_feature(feature) == AiUsageRecord::UNKNOWN_FEATURE
      return
    end

    feature
  end

  # Called right after with_instructions: marks the tools and instructions sent
  # so far as the prefix to keep, on the providers that cache only where told
  # to. Elsewhere it does nothing, because on OpenAI the same mark moves the
  # instructions into the input and changes the request the app has tested.
  def self.cache_prefix(chat, feature:)
    if explicit_caching_provider? && REPEATED_PREFIX_FEATURES.include?(feature)
      return chat.cache_until_here
    end

    chat
  end

  def self.explicit_caching_provider?
    EXPLICIT_CACHING_PROVIDERS.include?(Ai::Settings.current_llm_provider)
  end

  # An opaque id for the person behind a conversation, for the provider's abuse
  # monitoring. ruby_llm's Responses protocol drops with_end_user, so on
  # OpenAI's own API the field is written into the payload directly; an
  # OpenAI-compatible endpoint gets nothing, for the same reason it gets no
  # cache key.
  def self.identify_end_user(chat, end_user_id)
    return chat if end_user_id.blank?

    if Ai::Settings.standard_openai?
      return chat.before_request { |payload| payload[:safety_identifier] = end_user_id }
    end

    return chat if Ai::Settings.openai?

    chat.with_end_user(end_user_id)
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
      config.bedrock_api_key = Ai::Settings.bedrock_access_key_id
      config.bedrock_secret_key = Ai::Settings.bedrock_secret_access_key

      if Ai::Settings.bedrock_region.present?
        config.bedrock_region = Ai::Settings.bedrock_region
      end

      if proxy_uri.present?
        config.http_proxy = proxy_uri
      end
    end
  end

  def self.vertex_ai_context
    RubyLLM.context do |config|
      config.vertexai_project_id = Ai::Settings.vertex_ai_project
      config.vertexai_location = VERTEX_AI_LOCATION

      if proxy_uri.present?
        config.http_proxy = proxy_uri
      end

      if Ai::Settings.vertex_ai_credentials.present?
        config.vertexai_service_account_key = Ai::Settings.vertex_ai_credentials
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
