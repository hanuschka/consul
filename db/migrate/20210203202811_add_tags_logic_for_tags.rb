class AddTagsLogicForTags < ActiveRecord::Migration[5.1]
  def change
    add_column :tags, :custom_logic_category_code, :integer, default: 0
    add_column :tags, :custom_logic_subcategory_code, :integer, default: 0
  end
end

