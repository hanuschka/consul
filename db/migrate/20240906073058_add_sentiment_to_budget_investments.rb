class AddSentimentToBudgetInvestments < ActiveRecord::Migration[6.1]
  def change
    add_reference :budget_investments, :sentiment, foreign_key: true
  end
end
