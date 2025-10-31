class AddApiClientRelationsToResources < ActiveRecord::Migration[6.1]
  def change
    add_column :ideas, :api_client_created_id, :integer, index: true
    add_column :ideas, :api_client_last_updated_id, :integer, index: true

    add_column :proposals, :api_client_created_id, :integer, index: true
    add_column :proposals, :api_client_last_updated_id, :integer, index: true

    add_column :deficiency_reports, :api_client_created_id, :integer, index: true
    add_column :deficiency_reports, :api_client_last_updated_id, :integer, index: true

    add_column :budget_investments, :api_client_created_id, :integer, index: true
    add_column :budget_investments, :api_client_last_updated_id, :integer, index: true

    add_column :projekt_point_of_interest_pins, :api_client_created_id, :integer, index: true
    add_column :projekt_point_of_interest_pins, :api_client_last_updated_id, :integer, index: true
  end
end
