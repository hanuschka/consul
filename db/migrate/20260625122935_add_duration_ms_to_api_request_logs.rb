class AddDurationMsToApiRequestLogs < ActiveRecord::Migration[6.1]
  def change
    add_column :api_request_logs, :duration_ms, :float
  end
end
