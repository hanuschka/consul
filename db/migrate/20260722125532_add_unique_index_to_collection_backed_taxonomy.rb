class AddUniqueIndexToCollectionBackedTaxonomy < ActiveRecord::Migration[6.1]
  def change
    remove_index :projekt_labels, :masterportal_collection_id
    add_index :projekt_labels, [:projekt_phase_id, :masterportal_collection_id],
              unique: true,
              where: "masterportal_collection_id IS NOT NULL",
              name: "index_projekt_labels_on_phase_and_masterportal_collection"

    remove_index :projekt_point_of_interest_categories,
                 name: "index_poi_categories_on_masterportal_collection_id"
    add_index :projekt_point_of_interest_categories,
              [:projekt_phase_id, :masterportal_collection_id],
              unique: true,
              where: "masterportal_collection_id IS NOT NULL",
              name: "index_poi_categories_on_phase_and_masterportal_collection"
  end
end
