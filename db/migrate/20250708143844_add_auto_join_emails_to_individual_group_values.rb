class AddAutoJoinEmailsToIndividualGroupValues < ActiveRecord::Migration[6.1]
  def change
    add_column :individual_group_values, :auto_join_emails, :text, array: true, default: []
  end
end
