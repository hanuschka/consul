class CreateProjektsRegisteredAddressDistricts < ActiveRecord::Migration[6.1]
  def change
    create_table :projekts_registered_address_districts, id: false do |t|
      t.bigint :projekt_id, null: false
      t.bigint :registered_address_district_id, null: false
    end

    add_index :projekts_registered_address_districts,
              [:projekt_id, :registered_address_district_id],
              unique: true,
              name: "idx_projekts_ra_districts_on_projekt_and_district"
  end
end
