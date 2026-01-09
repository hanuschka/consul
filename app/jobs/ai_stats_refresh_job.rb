class AiStatsRefreshJob < ApplicationJob
  queue_as :default

  def perform(projekt_phase_id)
    projekt_phase = ProjektPhase.find(projekt_phase_id)
    projekt_phase.update(ai_stats_refresh_status: :processing)

    stats = AiAnalytics::GenerateAllStats.call(projekt_phase)
    projekt_phase.update(ai_stats: stats, ai_stats_refresh_status: :completed)
  rescue => e
    projekt_phase.update(ai_stats_refresh_status: :failed)
    raise e
  end
end
