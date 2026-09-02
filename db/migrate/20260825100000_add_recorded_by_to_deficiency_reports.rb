class AddRecordedByToDeficiencyReports < ActiveRecord::Migration[6.1]
  def change
    add_reference :deficiency_reports, :recorded_by, index: true
  end
end
