class AddNoticeTextToDeficiencyReportStatuses < ActiveRecord::Migration[6.1]
  def change
    add_column :deficiency_report_statuses, :notice_text, :text, default: ""
  end
end
