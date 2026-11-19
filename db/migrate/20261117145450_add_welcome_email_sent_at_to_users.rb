class AddWelcomeEmailSentAtToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :welcome_email_sent_at, :datetime

    up_only do
      execute "UPDATE users SET welcome_email_sent_at = confirmed_at WHERE confirmed_at IS NOT NULL"
    end
  end
end
