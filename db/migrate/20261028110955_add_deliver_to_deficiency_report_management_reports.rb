class AddDeliverToDeficiencyReportManagementReports < ActiveRecord::Migration[6.1]
  def change
    add_column :deficiency_report_management_reports, :deliver, :boolean, null: false, default: false
  end
end
