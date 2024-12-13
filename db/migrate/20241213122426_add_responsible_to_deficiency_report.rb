class AddResponsibleToDeficiencyReport < ActiveRecord::Migration[6.1]
  def up
    add_reference :deficiency_reports, :responsible, polymorphic: true

    execute <<-SQL.squish
      UPDATE deficiency_reports
      SET responsible_id = deficiency_report_officer_id,
          responsible_type = 'DeficiencyReport::Officer'
      WHERE deficiency_report_officer_id IS NOT NULL;
    SQL
  end

  def down
    execute <<-SQL.squish
      UPDATE deficiency_reports
      SET deficiency_report_officer_id = responsible_id
      WHERE responsible_type = 'DeficiencyReport::Officer';
    SQL

    remove_reference :deficiency_reports, :responsible, polymorphic: true
  end
end
