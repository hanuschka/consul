class AddConfirmationTokenToProjektEventRegistrations < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_event_registrations, :confirmation_token, :string
    add_column :projekt_event_registrations, :confirmed_at, :datetime
    add_index :projekt_event_registrations, :confirmation_token, unique: true
  end
end
