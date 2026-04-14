class AddAdminEmailsToProjektEvents < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_events, :admin_emails, :text
  end
end
