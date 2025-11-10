class RemoveDefaultFromReminderDelayInDeficiencyReportStatuses < ActiveRecord::Migration[6.1]
  def change
    change_column_null :deficiency_report_statuses, :reminder_delay, true
    change_column_default :deficiency_report_statuses, :reminder_delay, from: 14, to: nil
  end
end
