class AddDefaultToMapLocation < ActiveRecord::Migration[6.1]
  def change
    add_column :map_locations, :default, :boolean, default: false, null: false
  end
end
