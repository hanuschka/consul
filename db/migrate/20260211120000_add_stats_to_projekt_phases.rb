class AddStatsToProjektPhases < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_phases, :stats, :jsonb, default: {}, null: false
  end
end
