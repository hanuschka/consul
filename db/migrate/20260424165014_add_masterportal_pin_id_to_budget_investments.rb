class AddMasterportalPinIdToBudgetInvestments < ActiveRecord::Migration[6.1]
  def change
    add_column :budget_investments, :masterportal_pin_id, :bigint
    add_index :budget_investments, :masterportal_pin_id
  end
end
