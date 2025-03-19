class AddPreselectedToBudgetInvestments < ActiveRecord::Migration[6.1]
  def change
    add_column :budget_investments, :preselected, :boolean, default: false
  end
end
