class AddCostComponentsToAiUsageRecords < ActiveRecord::Migration[6.1]
  def change
    change_table :ai_usage_records, bulk: true do |t|
      t.decimal :cost_input, precision: 14, scale: 6, null: false, default: 0.0
      t.decimal :cost_output, precision: 14, scale: 6, null: false, default: 0.0
      t.decimal :cost_cache_read, precision: 14, scale: 6, null: false, default: 0.0
      t.decimal :cost_cache_write, precision: 14, scale: 6, null: false, default: 0.0
      t.decimal :cost_thinking, precision: 14, scale: 6, null: false, default: 0.0
    end
  end
end
