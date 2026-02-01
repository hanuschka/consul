class AiAnalytics::Polls::Evaluation < ApplicationService
  STAT_KEY = "evaluation"

  def initialize(poll)
    @poll = poll
  end

  def call
    AiAnalytics::Polls::Base.call(
      @poll,
      prompt: prompt,
      stat_key: STAT_KEY,
      output_schema: output_schema
    )
  end

  private

  def output_schema
    {
      type: "object",
      properties: {
        reports: {
          type: "array",
          items: {
            type: "object",
            properties: {
              title: { type: "string" },
              content: { type: "string" }
            },
            required: ["title", "content"],
            additionalProperties: false
          },
          minItems: 3,
          maxItems: 3
        }
      },
      required: ["reports"],
      additionalProperties: false
    }
  end

  def prompt
    @prompt ||= fetch_prompt
  end

  def fetch_prompt
    cache_key = "dt_api/consul_ai_prompts/ai_analytics_poll_evaluation/poll"

    parsed_response = DtApi::Caching.get_with_cache(
      cache_key,
      error_callback: -> { raise "DT API error: Failed to fetch ai_analytics_poll_evaluation prompt and no cached version available" }
    ) do
      DtApi::Client.new.consul_ai_prompts.get(
        :ai_analytics_poll_evaluation,
        resource_type: "poll"
      )
    end

    parsed_response.dig("consul_ai_prompt", "prompt")
  end
end
