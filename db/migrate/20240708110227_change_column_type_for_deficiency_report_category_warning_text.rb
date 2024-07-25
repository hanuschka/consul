class ChangeColumnTypeForDeficiencyReportCategoryWarningText < ActiveRecord::Migration[6.1]
  def up
    change_column :deficiency_report_categories, :warning_text, :text
  end

  def down
    change_column :deficiency_report_categories, :warning_text, :string
  end
end
