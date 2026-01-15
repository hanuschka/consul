class AiAnalytics::PollStatsRefresh < ApplicationJob
  queue_as :default

  def perform(poll_id)
    poll = ::Poll.find(poll_id)
    poll.update(ai_stats_refresh_status: "processing")

    # Simulate ai processing
    # sleep 20

    AiAnalytics::Polls::Evaluation.call(poll)
    AiAnalytics::Polls::Report.call(poll)

    poll.update(
      ai_stats_refresh_status: "completed",
      ai_stats_refreshed_at: Time.current
    )
  rescue => e
    Rails.logger.error("[AiAnalytics::PollStatsRefresh] Error: #{e.message}")
    poll&.update(ai_stats_refresh_status: "failed")
    raise e
  end
end
