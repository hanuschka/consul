# One instruction, one input, one answer — no tools, no stored history. That is
# the shape every WhatsApp AI service outside the router asks for, and this is
# where the choice of transport is read, so none of them has to know there are
# two. The three entry points mirror what those callers were already asking
# ruby_llm for: the cheap model on a clock, the configured model with no clock,
# and the same cheap model when the answer is prose rather than a schema.
module Ai::SingleTurn
  def self.fast_json(
    schema:, instructions:, input:, timeout_seconds:,
    feature: ::AiUsageRecord::UNKNOWN_FEATURE
  )
    profile = ::Ai::ModelProfile.fast

    if profile.responses?
      return ::OpenaiApi::Responses.json(
        schema: schema,
        instructions: instructions,
        input: input,
        model: profile.model,
        feature: feature,
        timeout_seconds: timeout_seconds
      )
    end

    ::Ai::RubyLlmFactory
      .chat_for(profile, feature: feature, request_timeout: timeout_seconds)
      .with_schema(schema)
      .with_instructions(instructions)
      .ask(input)
      .content
      .to_h
  end

  def self.json(
    schema:, instructions:, input:,
    feature: ::AiUsageRecord::UNKNOWN_FEATURE
  )
    profile = ::Ai::ModelProfile.default

    if profile.responses?
      return ::OpenaiApi::Responses.json(
        schema: schema,
        instructions: instructions,
        input: input,
        model: profile.model,
        feature: feature
      )
    end

    ::Ai::RubyLlmFactory
      .chat_for(profile, feature: feature)
      .with_schema(schema)
      .with_instructions(instructions)
      .ask(input)
      .content
      .to_h
  end

  def self.fast_text(
    instructions:, input:, timeout_seconds:,
    feature: ::AiUsageRecord::UNKNOWN_FEATURE
  )
    profile = ::Ai::ModelProfile.fast

    if profile.responses?
      return ::OpenaiApi::Responses.text(
        instructions: instructions,
        input: input,
        model: profile.model,
        feature: feature,
        timeout_seconds: timeout_seconds
      )
    end

    chat = ::Ai::RubyLlmFactory.chat_for(
      profile, feature: feature, request_timeout: timeout_seconds
    )

    chat.with_instructions(instructions)

    chat.ask(input).content.to_s
  end
end
