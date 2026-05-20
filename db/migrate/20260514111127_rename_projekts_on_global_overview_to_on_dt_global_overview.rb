class RenameProjektsOnGlobalOverviewToOnDtGlobalOverview < ActiveRecord::Migration[6.1]
  def change
    rename_column :projekts, :on_global_overview, :on_dt_global_overview
  end
end
