class AddAiStatsToProjektPhases < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_phases, :ai_stats, :jsonb, default: {}, null: false
  end
end
