class EnsureCostComponentsOnAiUsageRecords < ActiveRecord::Migration[6.1]
  COLUMNS = %i[cost_input cost_output cost_cache_read cost_cache_write cost_thinking].freeze

  # AddCostComponentsToAiUsageRecords shared its version with AddMunicipalPlanToProjekts, so a
  # database that ran the Vorhaben branch first has that version recorded without these columns.
  def up
    COLUMNS.each do |column|
      next if column_exists?(:ai_usage_records, column)

      add_column :ai_usage_records, column, :decimal, precision: 14, scale: 6, null: false, default: 0.0
    end
  end

  def down
  end
end
