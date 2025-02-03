class CreateDeficiencyReportOfficerGroups < ActiveRecord::Migration[6.1]
  def change
    create_table :deficiency_report_officer_groups do |t|
      t.string :name

      t.timestamps
    end
  end
end
