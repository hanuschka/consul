class AddRegistrationEnabledToProjektEvents < ActiveRecord::Migration[6.1]
  def up
    add_column :projekt_events, :registration_enabled, :boolean, default: false, null: false

    execute(<<~SQL)
      UPDATE projekt_events
      SET registration_enabled = TRUE
      WHERE max_attendees IS NOT NULL
    SQL
  end

  def down
    remove_column :projekt_events, :registration_enabled
  end
end
