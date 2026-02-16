class AddAiStatsRefreshedAtToProjektPhases < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_phases, :ai_stats_refreshed_at, :datetime
  end
end
