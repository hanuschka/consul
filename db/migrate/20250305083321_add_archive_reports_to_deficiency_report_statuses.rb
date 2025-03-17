class AddArchiveReportsToDeficiencyReportStatuses < ActiveRecord::Migration[6.1]
  def change
    add_column :deficiency_report_statuses, :archive_reports, :boolean, default: false
  end
end
