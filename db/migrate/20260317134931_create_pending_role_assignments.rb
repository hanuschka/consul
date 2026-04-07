class CreatePendingRoleAssignments < ActiveRecord::Migration[6.1]
  def change
    create_table :pending_role_assignments do |t|
      t.string :email, null: false
      t.string :role_type, null: false
      t.jsonb :metadata, default: {}
      t.bigint :created_by_id

      t.timestamps
    end

    add_index :pending_role_assignments, [:email, :role_type], unique: true
    add_index :pending_role_assignments, :email
    add_index :pending_role_assignments, :role_type
    add_foreign_key :pending_role_assignments, :users, column: :created_by_id
  end
end
