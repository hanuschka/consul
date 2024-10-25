class AddConditionalToBudgetBallot < ActiveRecord::Migration[6.1]
  def change
    add_column :budget_ballots, :conditional, :boolean, default: false
  end
end
