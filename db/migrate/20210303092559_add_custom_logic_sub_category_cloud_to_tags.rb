class AddCustomLogicSubCategoryCloudToTags < ActiveRecord::Migration[5.1]
  def change
    add_column :tags, :custom_logic_subcategory_cloud, :boolean
  end
end
