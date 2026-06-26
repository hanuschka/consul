class RenameCkeditorAssetTypesToAdminAssets < ActiveRecord::Migration[6.1]
  def up
    execute "UPDATE ckeditor_assets SET type = 'AdminImage' WHERE type = 'Ckeditor::Picture'"
    execute "UPDATE ckeditor_assets SET type = 'AdminDocument' WHERE type = 'Ckeditor::Document'"
    execute "UPDATE active_storage_attachments SET record_type = 'AdminAsset' WHERE record_type = 'Ckeditor::Asset'"
  end

  def down
    execute "UPDATE ckeditor_assets SET type = 'Ckeditor::Picture' WHERE type = 'AdminImage'"
    execute "UPDATE ckeditor_assets SET type = 'Ckeditor::Document' WHERE type = 'AdminDocument'"
    execute "UPDATE active_storage_attachments SET record_type = 'Ckeditor::Asset' WHERE record_type = 'AdminAsset'"
  end
end
