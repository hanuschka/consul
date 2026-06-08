class AddGeneratedImageToBudgetInvestments < ActiveRecord::Migration[6.1]
  def change
    add_column :budget_investments, :generated_image, :boolean, default: false, null: false
  end
end
