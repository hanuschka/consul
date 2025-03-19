class AddDefaultResponsibleToDeficiencyReportCategory < ActiveRecord::Migration[6.1]
  def up
    transaction do
      add_reference :deficiency_report_categories, :default_responsible, polymorphic: true

      execute <<-SQL.squish
        UPDATE deficiency_report_categories
        SET default_responsible_type = 'DeficiencyReport::Officer',
            default_responsible_id = deficiency_report_officer_id
        WHERE deficiency_report_officer_id IS NOT NULL;
      SQL

      remove_column :deficiency_report_categories, :deficiency_report_officer_id
    end
  end

  def down
    transaction do
      add_column :deficiency_report_categories, :deficiency_report_officer_id, :bigint

      execute <<-SQL.squish
        UPDATE deficiency_report_categories
        SET deficiency_report_officer_id = default_responsible_id
        WHERE default_responsible_type = 'DeficiencyReport::Officer';
      SQL

      remove_reference :deficiency_report_categories, :default_responsible, polymorphic: true
    end
  end
end
