class CreateDeficiencyReportReportProfiles < ActiveRecord::Migration[6.1]
  def change
    create_table :deficiency_report_report_profiles do |t|
      t.string :name, null: false
      t.text :building_blocks, array: true, default: [], null: false
      t.integer :category_ids, array: true, default: [], null: false
      t.integer :officer_group_ids, array: true, default: [], null: false
      t.integer :recipient_user_ids, array: true, default: [], null: false
      t.text :recipient_emails, array: true, default: [], null: false
      t.text :instructions
      t.string :frequency, null: false, default: "weekly"
      t.integer :weekday
      t.integer :day_of_month
      t.integer :hour, null: false, default: 8
      t.boolean :paused, null: false, default: false

      t.timestamps
    end
  end
end
