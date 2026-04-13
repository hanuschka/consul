class CreateApiRequestLogs < ActiveRecord::Migration[6.1]
  def change
    create_table :api_request_logs do |t|
      t.string :http_method, null: false
      t.string :request_path, null: false
      t.string :full_url
      t.jsonb :query_params, default: {}, null: false
      t.jsonb :body_params, default: {}, null: false
      t.integer :response_status
      t.integer :api_client_id
      t.timestamps
    end

    add_index :api_request_logs, :request_path
    add_index :api_request_logs, :api_client_id
    add_index :api_request_logs, :created_at
  end
end
