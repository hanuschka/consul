class AddAiStatsRefreshStatusToProjektPhases < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_phases, :ai_stats_refresh_status, :string
  end
end
