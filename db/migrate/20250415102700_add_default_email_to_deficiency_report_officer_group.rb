class AddDefaultEmailToDeficiencyReportOfficerGroup < ActiveRecord::Migration[6.1]
  def change
    add_column :deficiency_report_officer_groups, :default_email, :string
  end
end
