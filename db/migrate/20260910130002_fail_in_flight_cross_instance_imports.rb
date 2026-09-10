class FailInFlightCrossInstanceImports < ActiveRecord::Migration[6.1]
  # A cross-instance import used to create its projekt up front and fill it
  # from a job. That job is gone, so a row still claiming "processing" with no
  # local source to have been copied from has nothing left that could finish
  # it, and the poller would spin until it gives up. Marking it failed is what
  # makes it deletable again.
  def up
    execute <<~SQL
      UPDATE projekts
      SET copy_status = 'failed',
          copy_data = COALESCE(copy_data, '{}'::jsonb) ||
            '{"error": {"message": "import interrupted by an upgrade"}}'::jsonb
      WHERE copy_status = 'processing'
        AND copied_from_projekt_id IS NULL
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
