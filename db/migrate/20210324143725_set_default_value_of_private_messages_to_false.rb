class SetDefaultValueOfPrivateMessagesToFalse < ActiveRecord::Migration[5.1]
  def change
    change_column :users, :email_on_direct_message, :boolean, default: false
  end
end
