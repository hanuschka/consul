class AddCollectionTitleToMasterportalPins < ActiveRecord::Migration[6.1]
  def change
    add_column :masterportal_pins, :collection_title, :string
  end
end
