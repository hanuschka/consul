class AddManageAllProjektsToProjektManagers < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_managers, :manage_all_projekts, :boolean, default: false, null: false
  end
end
