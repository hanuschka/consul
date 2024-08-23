class AddLastNotificationSentToMemos < ActiveRecord::Migration[6.1]
  def change
    add_column :memos, :last_notification_sent_at, :datetime
  end
end
