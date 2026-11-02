class CreateDeficiencyReportManagementReports < ActiveRecord::Migration[6.1]
  def change
    create_table :deficiency_report_management_reports do |t|
      t.references :report_profile, null: false,
        foreign_key: { to_table: :deficiency_report_report_profiles, on_delete: :cascade },
        index: { name: "index_dr_management_reports_on_report_profile_id" }
      t.string :profile_name, null: false
      t.text :building_blocks, array: true, default: [], null: false
      t.datetime :period_start, null: false
      t.datetime :period_end, null: false
      t.string :status, null: false, default: "pending"
      t.string :trigger, null: false, default: "manual"
      t.jsonb :figures, null: false, default: {}
      t.jsonb :sections, null: false, default: []
      t.text :error_message
      t.datetime :generated_at
      t.datetime :sent_at

      t.timestamps
    end
  end
end
