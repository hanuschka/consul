class AddEmailTextsToProjektEvents < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_events, :confirmation_email_text, :text
    add_column :projekt_events, :waitlist_email_text, :text
  end
end
