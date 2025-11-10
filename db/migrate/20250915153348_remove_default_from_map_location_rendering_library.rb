class RemoveDefaultFromMapLocationRenderingLibrary < ActiveRecord::Migration[6.1]
  def change
    change_column_default :map_locations, :rendering_library, from: 0, to: nil
  end
end
