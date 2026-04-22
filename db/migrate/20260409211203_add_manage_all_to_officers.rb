class AddManageAllToOfficers < ActiveRecord::Migration[6.1]
  def change
    add_column :deficiency_report_officers, :manage_all, :boolean, default: false, null: false
    add_column :idea_officers, :manage_all, :boolean, default: false, null: false
  end
end
