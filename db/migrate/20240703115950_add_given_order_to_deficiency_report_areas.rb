class AddGivenOrderToDeficiencyReportAreas < ActiveRecord::Migration[6.1]
  def change
    add_column :deficiency_report_areas, :given_order, :integer
  end
end
