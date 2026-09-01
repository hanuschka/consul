class AddPolygonSupportToMasterportal < ActiveRecord::Migration[6.1]
  def change
    add_column :masterportal_pins, :geometry, :jsonb
    add_column :masterportal_collections, :feature_color, :string
  end
end
