class AddVersionToAiUsageRecords < ActiveRecord::Migration[6.1]
  def change
    add_column :ai_usage_records, :version, :bigint, null: false, default: 0
  end
end
