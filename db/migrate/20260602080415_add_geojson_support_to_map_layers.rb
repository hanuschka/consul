class AddGeojsonSupportToMapLayers < ActiveRecord::Migration[6.1]
  def change
    add_column :map_layers, :config, :jsonb, default: {}, null: false
  end
end
