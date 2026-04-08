class AddAiStatsRefreshFieldsToPolls < ActiveRecord::Migration[6.1]
  def change
    add_column :polls, :ai_stats_refresh_status, :string
    add_column :polls, :ai_stats_refreshed_at, :datetime
  end
end
