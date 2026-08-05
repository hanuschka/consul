class AddBrevoMemberSync < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :brevo_contact_id, :bigint
    add_column :users, :brevo_synced_at, :datetime

    add_index :users, :brevo_contact_id, unique: true, where: "brevo_contact_id IS NOT NULL"

    create_table :brevo_sync_logs do |t|
      t.string :source, null: false, default: "scheduled"
      t.string :status, null: false, default: "running"
      t.references :triggered_by, foreign_key: { to_table: :users }, index: true
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :contacts_count, null: false, default: 0
      t.integer :created_count, null: false, default: 0
      t.integer :erased_count, null: false, default: 0
      t.integer :skipped_count, null: false, default: 0
      t.integer :failed_count, null: false, default: 0
      t.text :error_message
      t.jsonb :details, null: false, default: []

      t.timestamps
    end

    add_index :brevo_sync_logs, :created_at
    add_index :brevo_sync_logs, [:status, :created_at]
  end
end
