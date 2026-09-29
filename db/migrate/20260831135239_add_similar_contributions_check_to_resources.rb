class AddSimilarContributionsCheckToResources < ActiveRecord::Migration[6.1]
  def change
    add_column :proposals, :similar_contributions_check_status, :string
    add_column :proposals, :similar_contributions_matches, :jsonb

    add_column :budget_investments, :similar_contributions_check_status, :string
    add_column :budget_investments, :similar_contributions_matches, :jsonb
  end
end
