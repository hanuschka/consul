class AiAnalytics::Polls::Evaluation < ApplicationService
  STAT_KEY = "evaluation"

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
          evaluation: {
            type: "array",
            items: {
              type: "object",
              properties: {
                title: {
                  type: "string",
                  description: "Plain text title without HTML formatting or markdown"
                },
                content: { type: "string" }
              },
              required: ["title", "content"],
              additionalProperties: false
            }
          }
        },
        required: ["evaluation"],
        additionalProperties: false
      }
    end

    def prompt
      @prompt ||= fetch_prompt
    end

    def fetch_prompt
      parsed_response =
        DtApi::Client.new(use_cache: true).consul_ai_prompts.get(
          :ai_analytics_poll_evaluation,
          resource_type: "poll"
        ).parsed_response
      parsed_response.dig("consul_ai_prompt", "prompt")
    end
end
