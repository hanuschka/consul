class AddGivenOrderToDeficiencyReportCategories < ActiveRecord::Migration[6.1]
  def change
    add_column :deficiency_report_categories, :given_order, :integer
  end
end
