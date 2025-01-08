class AddRegisteredAddressDistrictToRegisteredAddress < ActiveRecord::Migration[6.1]
  def change
    add_reference :registered_addresses, :registered_address_district, foreign_key: true
  end
end
