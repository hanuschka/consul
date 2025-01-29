class RenamePollManagersToOfficingManagers < ActiveRecord::Migration[6.1]
  def up
    transaction do
      create_table :officing_managers do |t|
        t.references :user, null: false, foreign_key: true
        t.timestamps
      end

      create_table :officing_manager_assignments do |t|
        t.references :officing_manager, null: false, foreign_key: true
        t.references :projekt_phase, null: false, foreign_key: true

        t.timestamps
      end

      add_index :officing_manager_assignments, [:officing_manager_id, :projekt_phase_id], unique: true,
                name: "index_om_assignments_on_om_id_and_projekt_phase_id"

      execute <<-SQL
        INSERT INTO officing_managers (user_id, created_at, updated_at)
        SELECT user_id, NOW(), NOW()
        FROM poll_managers
      SQL

      execute <<-SQL
        INSERT INTO officing_manager_assignments (officing_manager_id, projekt_phase_id, created_at, updated_at)
        SELECT poll_manager_id, polls.projekt_phase_id, NOW(), NOW()
        FROM poll_manager_assignments
        INNER JOIN polls on polls.id = poll_manager_assignments.poll_id
      SQL

      remove_foreign_key :poll_answers, :poll_managers
      rename_column :poll_answers, :poll_manager_id, :officing_manager_id
      add_foreign_key :poll_answers, :officing_managers

      remove_foreign_key :poll_voters, :poll_managers
      rename_column :poll_voters, :poll_manager_id, :officing_manager_id
      add_foreign_key :poll_voters, :officing_managers

      drop_table :poll_manager_assignments
      drop_table :poll_managers

      add_column :projekt_phases, :lock_on, :date
      execute <<-SQL
        UPDATE projekt_phases pp
        SET lock_on = (
          SELECT polls.lock_on
          FROM polls
          WHERE polls.projekt_phase_id = pp.id
          AND polls.lock_on IS NOT NULL
          ORDER BY polls.lock_on DESC
          LIMIT 1
        )
        WHERE EXISTS (
          SELECT 1
          FROM polls
          WHERE polls.projekt_phase_id = pp.id
          AND polls.lock_on IS NOT NULL
        );
      SQL
      remove_column :polls, :lock_on
    end
  end

  def down
    transaction do
      add_column :polls, :lock_on, :date
      remove_column :projekt_phases, :lock_on

      create_table :poll_managers do |t|
        t.references :user, null: false, foreign_key: true
        t.timestamps
      end

      create_table :poll_manager_assignments do |t|
        t.references :poll_manager, null: false, foreign_key: true
        t.references :poll, null: false, foreign_key: true

        t.timestamps
      end

      remove_foreign_key :poll_answers, :officing_managers
      rename_column :poll_answers, :officing_manager_id, :poll_manager_id
      add_foreign_key :poll_answers, :poll_managers

      remove_foreign_key :poll_voters, :officing_managers
      rename_column :poll_voters, :officing_manager_id, :poll_manager_id
      add_foreign_key :poll_voters, :poll_managers

      remove_index :officing_manager_assignments, name: "index_om_assignments_on_om_id_and_projekt_phase_id"

      drop_table :officing_manager_assignments
      drop_table :officing_managers
    end
  end
end
