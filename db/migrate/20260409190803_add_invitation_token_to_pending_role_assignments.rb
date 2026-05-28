class AddInvitationTokenToPendingRoleAssignments < ActiveRecord::Migration[6.1]
  def change
    add_column :pending_role_assignments, :invitation_token, :string
    add_index :pending_role_assignments, :invitation_token, unique: true, where: "invitation_token IS NOT NULL"
  end
end
