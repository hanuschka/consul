class AddLastStatusChangedOnToDeficiencyReports < ActiveRecord::Migration[6.1]
  def change
    add_column :deficiency_reports, :status_changed_at, :datetime
    add_column :deficiency_reports, :archived_at, :datetime

    execute <<-SQL
      UPDATE deficiency_reports
      SET status_changed_at = updated_at
    SQL
  end
end
