class AddApprovePermissionToModeratingProjektManagers < ActiveRecord::Migration[6.1]
  def up
    updated = update(<<~SQL)
      UPDATE projekt_manager_assignments
      SET permissions = array_append(permissions, 'approve'), updated_at = NOW()
      WHERE 'moderate' = ANY(permissions)
        AND NOT ('approve' = ANY(permissions))
    SQL

    say "added approve to #{updated} projekt manager assignments"
  end

  def down
  end
end
