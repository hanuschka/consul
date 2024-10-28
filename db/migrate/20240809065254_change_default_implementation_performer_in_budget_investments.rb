class ChangeDefaultImplementationPerformerInBudgetInvestments < ActiveRecord::Migration[6.1]
  def change
    change_column_default :budget_investments, :implementation_performer, from: "0", to: "1"
  end
end
