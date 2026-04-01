class ChangeDefaultProtocolInMapLayers < ActiveRecord::Migration[6.1]
  def change
    change_column_default :map_layers, :protocol, from: 0, to: 1
  end
end
