class AddFailedRequestCountToAiUsageRecords < ActiveRecord::Migration[6.1]
  def change
    add_column :ai_usage_records, :failed_request_count, :integer, null: false, default: 0
  end
end
