class AddValuatorExplanationToBudgetInvestment < ActiveRecord::Migration[6.1]
  def up
    add_column :budget_investments, :valuator_explanation, :text

    execute <<-SQL.squish
      UPDATE budget_investments
      SET valuator_explanation = COALESCE(unfeasibility_explanation, price_explanation)
    SQL
  end

  def down
    remove_column :budget_investments, :valuator_explanation
  end
end
