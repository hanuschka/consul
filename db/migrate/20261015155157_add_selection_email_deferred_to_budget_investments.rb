class AddSelectionEmailDeferredToBudgetInvestments < ActiveRecord::Migration[6.1]
  def change
    add_column :budget_investments, :selection_email_deferred, :boolean, default: false, null: false
  end
end
