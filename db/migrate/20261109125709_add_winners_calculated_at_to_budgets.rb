class AddWinnersCalculatedAtToBudgets < ActiveRecord::Migration[6.1]
  def change
    add_column :budgets, :winners_calculated_at, :datetime
  end
end
