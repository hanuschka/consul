class AddMasterportalCollectionToProjektPointOfInterestCategories < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_point_of_interest_categories, :masterportal_collection_id, :integer
    add_index :projekt_point_of_interest_categories, :masterportal_collection_id,
              name: "index_poi_categories_on_masterportal_collection_id"
  end
end
