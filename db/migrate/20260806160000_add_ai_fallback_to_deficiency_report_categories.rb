class AddAiFallbackToDeficiencyReportCategories < ActiveRecord::Migration[6.1]
  def change
    add_column :deficiency_report_categories, :ai_fallback, :boolean, default: false, null: false
  end
end
