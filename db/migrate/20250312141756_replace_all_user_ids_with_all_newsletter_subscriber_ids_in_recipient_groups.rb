class ReplaceAllUserIdsWithAllNewsletterSubscriberIdsInRecipientGroups < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL
      UPDATE recipient_groups
      SET access_method = 'all_newsletter_subscriber_ids'
      WHERE access_method = 'all_user_ids';
    SQL
  end

  def down
    execute <<-SQL
      UPDATE recipient_groups
      SET access_method = 'all_user_ids'
      WHERE access_method = 'all_newsletter_subscriber_ids';
    SQL
  end
end
