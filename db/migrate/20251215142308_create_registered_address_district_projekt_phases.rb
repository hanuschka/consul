class CreateRegisteredAddressDistrictProjektPhases < ActiveRecord::Migration[6.1]
  def change
    create_table :registered_address_district_projekt_phases do |t|
      t.references :registered_address_district,
        foreign_key: true,
        index: { name: "index_rad_projekt_phases_on_rad_id" }
      t.references :projekt_phase,
        foreign_key: true,
        index: { name: "index_rad_projekt_phases_on_projekt_phase_id" }
      t.timestamps
    end
  end
end
