class CreateProjektEventRegistrations < ActiveRecord::Migration[6.1]
  def change
    create_table :projekt_event_registrations do |t|
      t.references :projekt_event, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :status, null: false, default: "confirmed"

      t.timestamps
    end

    add_index :projekt_event_registrations, [:projekt_event_id, :user_id],
              unique: true,
              where: "user_id IS NOT NULL",
              name: "index_projekt_event_registrations_on_event_and_user"

    add_index :projekt_event_registrations, [:projekt_event_id, :email],
              unique: true,
              where: "user_id IS NULL AND email IS NOT NULL",
              name: "index_projekt_event_registrations_on_event_and_email"
  end
end
