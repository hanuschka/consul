class CreatePollManagerAssignments < ActiveRecord::Migration[6.1]
  def change
    create_table :poll_manager_assignments do |t|
      t.references :poll, foreign_key: true
      t.references :poll_manager, foreign_key: true

      t.timestamps
    end

    add_index :poll_manager_assignments, [:poll_id, :poll_manager_id], unique: true
  end
end
