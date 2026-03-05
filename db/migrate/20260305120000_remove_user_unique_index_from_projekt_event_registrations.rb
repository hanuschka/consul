class RemoveUserUniqueIndexFromProjektEventRegistrations < ActiveRecord::Migration[6.1]
  def up
    remove_index :projekt_event_registrations,
                 name: "index_projekt_event_registrations_on_event_and_user"

    remove_index :projekt_event_registrations,
                 name: "index_projekt_event_registrations_on_event_and_email"
  end

  def down
    add_index :projekt_event_registrations, [:projekt_event_id, :email],
              unique: true,
              where: "user_id IS NULL AND email IS NOT NULL",
              name: "index_projekt_event_registrations_on_event_and_email"

    add_index :projekt_event_registrations, [:projekt_event_id, :user_id],
              unique: true,
              where: "user_id IS NOT NULL",
              name: "index_projekt_event_registrations_on_event_and_user"
  end
end
