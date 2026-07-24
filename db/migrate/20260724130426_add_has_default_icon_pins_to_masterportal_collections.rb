class AddHasDefaultIconPinsToMasterportalCollections < ActiveRecord::Migration[6.1]
  def change
    add_column :masterportal_collections, :has_default_icon_pins, :boolean, default: false, null: false
  end
end
