class UpdateValuatorExplanationInBudgetInvestments < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      UPDATE budget_investments
      SET valuator_explanation = COALESCE(NULLIF(unfeasibility_explanation, ''), price_explanation)
      WHERE valuator_explanation IS NULL OR valuator_explanation = '';
    SQL
  end

  def down
  end
end
