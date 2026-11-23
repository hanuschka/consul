class WidenBudgetInvestmentsFeasibility < ActiveRecord::Migration[7.2]
  def up
    change_column :budget_investments, :feasibility, :string, limit: 30, default: "undecided"
  end

  def down
    change_column :budget_investments, :feasibility, :string, limit: 15, default: "undecided"
  end
end
