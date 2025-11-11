class CreateDeficiencyReportFeedbackForms < ActiveRecord::Migration[6.1]
  def change
    create_table :deficiency_report_feedback_forms do |t|
      t.references :deficiency_report, foreign_key: true

      t.integer :overall_satisfaction
      t.integer :response_time_satisfaction
      t.integer :communication_satisfaction
      t.boolean :resolved

      t.text :what_liked_note
      t.text :what_improve_note

      t.timestamps
    end
  end
end
