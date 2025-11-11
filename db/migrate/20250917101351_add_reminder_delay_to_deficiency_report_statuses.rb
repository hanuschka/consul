class AddReminderDelayToDeficiencyReportStatuses < ActiveRecord::Migration[6.1]
  def change
    add_column :deficiency_report_statuses, :reminder_delay, :integer, default: 14, null: false
  end
end
