class AddRegisteredAddressDistrictToMapLocation < ActiveRecord::Migration[6.1]
  def change
    add_reference :map_locations, :registered_address_district, foreign_key: true
  end
end
