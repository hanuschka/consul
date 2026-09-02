class CreateAiUsageRecords < ActiveRecord::Migration[6.1]
  def change
    create_table :ai_usage_records do |t|
      t.date :period_month, null: false
      t.string :feature, null: false
      t.string :provider, null: false
      t.string :model, null: false

      t.integer :request_count, null: false, default: 0
      t.integer :unpriced_request_count, null: false, default: 0

      t.bigint :input_tokens, null: false, default: 0
      t.bigint :output_tokens, null: false, default: 0
      t.bigint :cache_read_tokens, null: false, default: 0
      t.bigint :cache_write_tokens, null: false, default: 0
      t.bigint :thinking_tokens, null: false, default: 0

      t.float :audio_seconds, null: false, default: 0.0
      t.decimal :cost_total, precision: 14, scale: 6, null: false, default: 0.0

      t.timestamps

      t.index [:period_month, :feature, :provider, :model],
              unique: true, name: "index_ai_usage_records_on_period_and_breakdown"
      t.index [:period_month], name: "index_ai_usage_records_on_period_month"
    end
  end
end
