class AddTieResolvedAtToBudgets < ActiveRecord::Migration[6.1]
  def change
    add_column :budgets, :tie_resolved_at, :datetime
  end
end
