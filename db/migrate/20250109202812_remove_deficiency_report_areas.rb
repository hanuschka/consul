class RemoveDeficiencyReportAreas < ActiveRecord::Migration[6.1]
  def up
    remove_reference :deficiency_reports, :deficiency_report_area, foreign_key: true if column_exists? :deficiency_reports, :deficiency_report_area_id
    remove_reference :map_locations, :deficiency_report_area, foreign_key: true if column_exists? :map_locations, :deficiency_report_area_id

    drop_table :deficiency_report_areas if table_exists? :deficiency_report_areas
  end

  def down
  end
end
