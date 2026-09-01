class AddMasterportalCollectionToProjektLabels < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_labels, :masterportal_collection_id, :integer
    add_index :projekt_labels, :masterportal_collection_id
  end
end
