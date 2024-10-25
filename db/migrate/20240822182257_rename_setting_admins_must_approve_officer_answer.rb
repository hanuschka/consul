class RenameSettingAdminsMustApproveOfficerAnswer < ActiveRecord::Migration[6.1]
  def up
    if table_exists?(:settings)
      execute <<-SQL
        UPDATE settings
        SET key = 'deficiency_reports.officers_can_edit_assigned_reports'
        WHERE key = 'deficiency_reports.admins_must_approve_officer_answer';
      SQL
    else
      Rails.logger.warn "Settings table does not exist, skipping migration."
    end
  end

  def down
    if table_exists?(:settings)
      execute <<-SQL
        UPDATE settings
        SET key = 'deficiency_reports.admins_must_approve_officer_answer'
        WHERE key = 'deficiency_reports.officers_can_edit_assigned_reports';
      SQL
    else
      Rails.logger.warn "Settings table does not exist, skipping rollback."
    end
  end
end
