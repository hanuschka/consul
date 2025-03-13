class AddMaxPreselectedToBudgets < ActiveRecord::Migration[6.1]
  def change
    add_column :budgets, :max_preselected, :integer, default: 0
  end
end
