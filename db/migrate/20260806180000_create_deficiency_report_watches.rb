class CreateDeficiencyReportWatches < ActiveRecord::Migration[6.1]
  def change
    create_table :deficiency_report_watches do |t|
      t.bigint :deficiency_report_id, null: false
      t.bigint :user_id, null: false

      t.timestamps

      t.index [:deficiency_report_id, :user_id], unique: true, name: "index_dr_watches_on_report_and_user"
      t.index [:user_id], name: "index_dr_watches_on_user_id"
    end

    add_foreign_key :deficiency_report_watches, :deficiency_reports
    add_foreign_key :deficiency_report_watches, :users
  end
end
