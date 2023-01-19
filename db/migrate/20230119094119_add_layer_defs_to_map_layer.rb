class AddLayerDefsToMapLayer < ActiveRecord::Migration[5.2]
  def change
    add_column :map_layers, :layer_defs, :string
  end
end
