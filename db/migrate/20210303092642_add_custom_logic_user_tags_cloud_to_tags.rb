class AddCustomLogicUserTagsCloudToTags < ActiveRecord::Migration[5.1]
  def change
    add_column :tags, :custom_logic_usertags_cloud, :boolean
  end
end
