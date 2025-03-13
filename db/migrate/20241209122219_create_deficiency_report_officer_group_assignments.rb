class CreateDeficiencyReportOfficerGroupAssignments < ActiveRecord::Migration[6.1]
  def change
    create_table :deficiency_report_officer_group_assignments do |t|
      t.references :deficiency_report_officer, null: false, foreign_key: true, index: { name: "index_dr_officer_group_assignments_on_dr_officer_id" }
      t.references :deficiency_report_officer_group, null: false, foreign_key: true, index: { name: "index_dr_officer_group_assignments_on_dr_officer_group_id" }

      t.timestamps
    end

    add_index :deficiency_report_officer_group_assignments, [:deficiency_report_officer_id, :deficiency_report_officer_group_id], unique: true,
      name: "index_dr_officer_group_assignments_on_dro_id_and_drog_id"
  end
end
