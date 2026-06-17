class RenameCkeditorAssetsToAdminAssets < ActiveRecord::Migration[6.1]
  def change
    rename_table :ckeditor_assets, :admin_assets
  end
end
