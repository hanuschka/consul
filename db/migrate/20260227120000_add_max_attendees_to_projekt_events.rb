class AddMaxAttendeesToProjektEvents < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_events, :max_attendees, :integer, default: nil
  end
end
