module AiAnalytics
  class ProjektPhaseStatsRefresh < ApplicationJob
    queue_as :default

    def perform(projekt_phase_id)
      projekt_phase = ProjektPhase.find(projekt_phase_id)
      projekt_phase.update(ai_stats_refresh_status: :processing)

      # Simulate ai processing
      # sleep 120
      # stats = {}

      stats = AiAnalytics::GenerateAllStats.call(projekt_phase)

      projekt_phase.update(
        ai_stats: stats,
        ai_stats_refresh_status: :completed,
        ai_stats_refreshed_at: Time.current
      )
    rescue => e
      projekt_phase.update(ai_stats_refresh_status: :failed)
      raise e
    end
  end
end
