class ProjektsRenameForGlobalOverviewToOnGlobalOverview < ActiveRecord::Migration[6.1]
  def change
    rename_column :projekts, :for_global_overview, :on_global_overview
  end
end
