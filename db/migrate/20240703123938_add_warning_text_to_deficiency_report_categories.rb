class AddWarningTextToDeficiencyReportCategories < ActiveRecord::Migration[6.1]
  def change
    add_column :deficiency_report_categories, :warning_text, :string, default: ''
  end
end
