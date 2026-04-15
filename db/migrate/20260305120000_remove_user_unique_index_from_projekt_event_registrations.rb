class RemoveUserUniqueIndexFromProjektEventRegistrations < ActiveRecord::Migration[6.1]
  def up
    if index_exists?(:projekt_event_registrations, [:projekt_event_id, :user_id], name: "index_projekt_event_registrations_on_event_and_user")
      remove_index :projekt_event_registrations,
                   name: "index_projekt_event_registrations_on_event_and_user"
    end

    if index_exists?(:projekt_event_registrations, [:projekt_event_id, :email], name: "index_projekt_event_registrations_on_event_and_email")
      remove_index :projekt_event_registrations,
                   name: "index_projekt_event_registrations_on_event_and_email"
    end
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
