class DropAhoyVisitsAndEvents < ActiveRecord::Migration[7.2]
  def up
    drop_table :ahoy_events, if_exists: true
    drop_table :ahoy_events_old, if_exists: true
    drop_table :ahoy_visits, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
