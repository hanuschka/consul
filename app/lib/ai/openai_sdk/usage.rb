module Ai::OpenaiSdk::Usage
  PROVIDER = "openai".freeze

  # Recorded through the same service the ruby_llm path records through, off a
  # real RubyLLM::Message rather than a stand-in. The message already knows how
  # to price a model from the gem's own registry, and that is what keeps the
  # cost column of the usage table populated on this transport as well —
  # a nil cost counts every call as unpriced instead.
  def self.record(response:, feature:, requested_model:)
    ::AiUsageRecords::RecordChatUsage.call(
      message: message_for(response),
      feature: feature,
      provider: PROVIDER,
      requested_model: requested_model
    )
  rescue => e
    Rails.logger.error("[AiUsageRecord] Failed to record usage for #{feature}: #{e.message}")
  end

  # Reasoning tokens are billed as output tokens and reported inside the output
  # detail, so they are passed on their own key rather than added to the total:
  # the usage table counts them separately.
  def self.message_for(response)
    usage = response.usage

    ::RubyLLM::Message.new(
      role: :assistant,
      content: "",
      model_id: response.model,
      input_tokens: usage&.input_tokens,
      output_tokens: usage&.output_tokens,
      cached_tokens: usage&.input_tokens_details&.cached_tokens,
      reasoning_tokens: usage&.output_tokens_details&.reasoning_tokens
    )
  end
end
