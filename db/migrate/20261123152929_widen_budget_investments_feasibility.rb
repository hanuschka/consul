class WidenBudgetInvestmentsFeasibility < ActiveRecord::Migration[7.2]
  def up
    change_column :budget_investments, :feasibility, :string, limit: 30, default: "undecided"
  end

  def down
    execute <<~SQL.squish
      UPDATE budget_investments
      SET feasibility = 'feasible'
      WHERE feasibility = 'feasible_with_changes'
    SQL

    change_column :budget_investments, :feasibility, :string, limit: 15, default: "undecided"
  end
end
