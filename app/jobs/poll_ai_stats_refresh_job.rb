class PollAiStatsRefreshJob < ApplicationJob
  queue_as :default

  def perform(poll_id)
    poll = Poll.find(poll_id)
    poll.update(ai_stats_refresh_status: "processing")

    sleep 20
    # TEMP--------------------------------
    # AiAnalytics::Poll::Evaluation.call(poll)
    # AiAnalytics::Poll::Report.call(poll)
    # TEMP--------------------------------

    poll.update(
      ai_stats_refresh_status: "completed",
      ai_stats_refreshed_at: Time.current
    )
  rescue => e
    Rails.logger.error("[PollAiStatsRefreshJob] Error: #{e.message}")
    poll&.update(ai_stats_refresh_status: "failed")
    raise e
  end
end
