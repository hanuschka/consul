class AddAdminAcceptedToDeficiencyReports < ActiveRecord::Migration[6.1]
  def change
    add_column :deficiency_reports, :admin_accepted, :boolean, default: false
  end
end
