class AddPublishedAtToBudgetInvestments < ActiveRecord::Migration[6.1]
  def change
    add_column :budget_investments, :published_at, :datetime
  end
end
