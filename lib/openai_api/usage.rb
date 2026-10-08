module OpenaiApi::Usage
  PROVIDER = "openai".freeze

  # Recorded through the same service the ruby_llm path records through, off a
  # real RubyLLM::Message rather than a stand-in. The message already knows how
  # to price a model from the gem's own registry, and that is what keeps the
  # cost column of the usage table populated on this transport as well —
  # a nil cost counts every call as unpriced instead.
  def self.record(response:, feature:, requested_model:)
    message = message_for(response)

    ::AiUsageRecords::RecordAttemptUsage.call(
      feature: feature,
      provider: PROVIDER,
      model: message.model.presence || requested_model,
      status: :succeeded,
      tokens: message.tokens,
      cost: message.cost
    )
  rescue => e
    Rails.logger.error("[AiUsageRecord] Failed to record usage for #{feature}: #{e.message}")
  end

  # No response means nothing to read a model or tokens off, so the attempt is
  # booked against the model that was asked for. A timed-out request may still
  # have been billed, and the failed count is what shows a provider struggling.
  def self.record_failure(feature:, requested_model:)
    ::AiUsageRecords::RecordAttemptUsage.call(
      feature: feature,
      provider: PROVIDER,
      model: requested_model,
      status: :failed,
      tokens: nil,
      cost: nil
    )
  rescue => e
    Rails.logger.error("[AiUsageRecord] Failed to record failed attempt for #{feature}: #{e.message}")
  end

  def self.message_for(response)
    usage = response.usage

    ::RubyLLM::Message.new(
      role: :assistant,
      content: "",
      model: response.model,
      input_tokens: uncached_input_tokens(usage),
      output_tokens: usage&.output_tokens,
      cache_read_tokens: usage&.cached_tokens,
      thinking_tokens: usage&.reasoning_tokens
    )
  end

  # ruby_llm counts input and cache reads apart and prices each once, the way its
  # own Responses parser reports them. OpenAI's input_tokens include the cached
  # ones, which passed through unchanged would be priced twice.
  def self.uncached_input_tokens(usage)
    return if usage&.input_tokens.nil?

    [usage.input_tokens.to_i - usage.cached_tokens.to_i, 0].max
  end
end
