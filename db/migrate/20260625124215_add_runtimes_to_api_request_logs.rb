class AddRuntimesToApiRequestLogs < ActiveRecord::Migration[6.1]
  def change
    add_column :api_request_logs, :db_runtime, :float
    add_column :api_request_logs, :view_runtime, :float
  end
end
