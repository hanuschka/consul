class AddPendingEmailsChecksToInvestments < ActiveRecord::Migration[6.1]
  def up
    add_column :budget_investments, :email_on_feasibility_sent_at, :time
    add_column :budget_investments, :email_on_selected_sent_at, :time

    if column_exists?(:budget_investments, :unfeasible_email_sent_at)
      execute <<~SQL
        UPDATE budget_investments
        SET email_on_feasibility_sent_at = unfeasible_email_sent_at
        WHERE unfeasible_email_sent_at IS NOT NULL
      SQL
    end
  end

  def down
    remove_column :budget_investments, :email_on_feasibility_sent_at
    remove_column :budget_investments, :email_on_selected_sent_at
  end
end
