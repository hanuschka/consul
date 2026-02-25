class AiAnalytics::Polls::Report < ApplicationService
  STAT_KEY = "report"

  def initialize(poll)
    @poll = poll
  end

  def call
    AiAnalytics::Polls::Base.call(
      @poll,
      prompt:,
      stat_key: STAT_KEY,
      output_schema:
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
      parsed_response =
        DtApi::Client.new(use_cache: true).consul_ai_prompts.get(
          :ai_analytics_poll_report,
          resource_type: "poll"
        ).parsed_response
      parsed_response.dig("consul_ai_prompt", "prompt")
    end
end
