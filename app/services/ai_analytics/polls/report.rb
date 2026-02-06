class AiAnalytics::Polls::Report < ApplicationService
  STAT_KEY = "report"

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
        report: {
          type: "object",
          properties: {
            title: { type: "string" },
            content: { type: "string" }
          },
          required: ["title", "content"],
          additionalProperties: false
        }
      },
      required: ["report"],
      additionalProperties: false
    }
  end

  def prompt
    @prompt ||= fetch_prompt
  end

  def fetch_prompt
    cache_key = "dt_api/consul_ai_prompts/ai_analytics_poll_report/poll"

    parsed_response = DtApi::Caching.get_with_cache(cache_key) do
      DtApi::Client.new.consul_ai_prompts.get(
        :ai_analytics_poll_report,
        resource_type: "poll"
      )
    end

    parsed_response.dig("consul_ai_prompt", "prompt")
  end
end
