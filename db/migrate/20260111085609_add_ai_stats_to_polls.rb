class AddAiStatsToPolls < ActiveRecord::Migration[6.1]
  def change
    add_column :polls, :ai_stats, :jsonb, default: {}
  end
end
