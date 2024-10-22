class AddDeficiencyReportOfficerToDeficiencyReportCategory < ActiveRecord::Migration[6.1]
  def change
    add_reference :deficiency_report_categories, :deficiency_report_officer, foreign_key: true, index: { name: "index_dr_categories_on_dr_officer_id" }
  end
end
