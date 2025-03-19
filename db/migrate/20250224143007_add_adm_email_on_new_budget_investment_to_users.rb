class AddAdmEmailOnNewBudgetInvestmentToUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :adm_email_on_new_budget_investment, :boolean, default: false
  end
end
