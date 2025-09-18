class AddRenderingLibraryToMapLocation < ActiveRecord::Migration[6.1]
  def change
    add_column :map_locations, :rendering_library, :integer, default: 0, null: false
  end
end
