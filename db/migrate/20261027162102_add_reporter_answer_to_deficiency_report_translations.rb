class AddReporterAnswerToDeficiencyReportTranslations < ActiveRecord::Migration[6.1]
  def change
    add_column :deficiency_report_translations, :reporter_answer, :text
  end
end
