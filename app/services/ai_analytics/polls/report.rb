class AiAnalytics::Polls::Report < ApplicationService
  STAT_KEY = "report"

  def initialize(poll)
    @poll = poll
  end

  def call
    AiAnalytics::Polls::Base.call(@poll, prompt: prompt, stat_key: STAT_KEY)
  end

  private

  def prompt
    @prompt ||= fetch_prompt
  end

  def fetch_prompt
    response = DtApi::Client.new.consul_ai_prompts.get(
      :ai_analytics_poll_report,
      resource_type: "poll"
    )

    unless response.success?
      raise "DT API error: #{response.code} - #{response.message}"
    end

    response.dig("consul_ai_prompt", "prompt")
  end
end
