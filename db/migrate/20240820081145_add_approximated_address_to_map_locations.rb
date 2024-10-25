class AddApproximatedAddressToMapLocations < ActiveRecord::Migration[6.1]
  def change
    add_column :map_locations, :approximated_address, :string
  end
end
