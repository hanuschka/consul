class AddContainsShapesToMasterportalCollections < ActiveRecord::Migration[6.1]
  def change
    add_column :masterportal_collections, :contains_shapes, :boolean, default: false, null: false
  end
end
