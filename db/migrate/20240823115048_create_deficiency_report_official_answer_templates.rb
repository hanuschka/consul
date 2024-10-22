class CreateDeficiencyReportOfficialAnswerTemplates < ActiveRecord::Migration[6.1]
  def change
    create_table :deficiency_report_official_answer_templates do |t|
      t.string :title
      t.text :text

      t.timestamps
    end
  end
end
