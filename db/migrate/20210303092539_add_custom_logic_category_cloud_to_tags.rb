class AddCustomLogicCategoryCloudToTags < ActiveRecord::Migration[5.1]
  def change
    add_column :tags, :custom_logic_category_cloud, :boolean
  end
end
