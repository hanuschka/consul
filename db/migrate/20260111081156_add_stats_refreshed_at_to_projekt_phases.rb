class AddStatsRefreshedAtToProjektPhases < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_phases, :stats_refreshed_at, :datetime
  end
end
