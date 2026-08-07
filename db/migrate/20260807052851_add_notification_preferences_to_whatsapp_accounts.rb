class AddNotificationPreferencesToWhatsappAccounts < ActiveRecord::Migration[6.1]
  # Columns rather than a jsonb blob so a broadcast job filters its audience in
  # SQL instead of loading every subscribed account to ask each one in Ruby.
  # All default true: the catalog's default is every notification type on.
  def change
    add_column :whatsapp_accounts, :notify_new_projekt, :boolean, default: true, null: false
    add_column :whatsapp_accounts, :notify_deadline_approaching, :boolean, default: true, null: false
    add_column :whatsapp_accounts, :notify_deadline_passed, :boolean, default: true, null: false
    add_column :whatsapp_accounts, :notify_new_supports, :boolean, default: true, null: false
    add_column :whatsapp_accounts, :notify_new_comments, :boolean, default: true, null: false
    add_column :whatsapp_accounts, :notify_moderation_decision, :boolean, default: true, null: false
  end
end
