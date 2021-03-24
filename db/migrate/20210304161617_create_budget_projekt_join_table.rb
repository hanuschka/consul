class CreateBudgetProjektJoinTable < ActiveRecord::Migration[5.1]
  def change
    create_join_table :budgets, :projekts do |t|
      # t.index [:budget_id, :projekt_id]
      t.index [:projekt_id, :budget_id], unique: true
    end
  end
end
