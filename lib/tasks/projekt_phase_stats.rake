namespace :projekt_phase_stats do
  desc "Refresh stats for phases with recent activity"
  task refresh: :environment do
    ProjektPhase::StatsRefreshService.new.call
  end
end
