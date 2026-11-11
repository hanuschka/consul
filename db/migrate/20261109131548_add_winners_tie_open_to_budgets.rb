class AddWinnersTieOpenToBudgets < ActiveRecord::Migration[6.1]
  def change
    add_column :budgets, :winners_tie_open, :boolean, default: false, null: false
  end
end
