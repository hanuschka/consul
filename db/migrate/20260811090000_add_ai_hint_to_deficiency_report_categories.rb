class AddAiHintToDeficiencyReportCategories < ActiveRecord::Migration[6.1]
  def change
    add_column :deficiency_report_categories, :ai_hint, :text
    add_column :deficiency_report_subcategories, :ai_hint, :text
  end
end
