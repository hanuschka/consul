class CreateDeficiencyReportManagers < ActiveRecord::Migration[6.1]
  def change
    create_table :deficiency_report_managers do |t|
      t.references :user, foreign_key: true

      t.timestamps
    end
  end
end
