require "rails_helper"
require Rails.root.join("db/migrate/20261028200002_add_approve_permission_to_moderating_projekt_managers")

describe AddApprovePermissionToModeratingProjektManagers do
  def migrate
    ActiveRecord::Migration.suppress_messages { AddApprovePermissionToModeratingProjektManagers.new.up }
  end

  it "adds 'approve' to every assignment with 'moderate'" do
    moderating = create(:projekt_manager_assignment, permissions: %w[manage moderate])

    migrate

    expect(moderating.reload.permissions).to eq %w[manage moderate approve]
  end

  it "leaves assignments without 'moderate' untouched" do
    managing = create(:projekt_manager_assignment, permissions: %w[manage])

    migrate

    expect(managing.reload.permissions).to eq %w[manage]
  end

  it "does not add 'approve' twice" do
    approving = create(:projekt_manager_assignment, permissions: %w[moderate approve])

    migrate

    expect(approving.reload.permissions).to eq %w[moderate approve]
  end
end
