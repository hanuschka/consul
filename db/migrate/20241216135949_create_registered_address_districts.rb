class CreateRegisteredAddressDistricts < ActiveRecord::Migration[6.1]
  def change
    create_table :registered_address_districts do |t|
      t.string :name

      t.timestamps
    end
  end
end
