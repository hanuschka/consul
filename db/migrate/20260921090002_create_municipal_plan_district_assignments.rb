class CreateMunicipalPlanDistrictAssignments < ActiveRecord::Migration[6.1]
  def change
    create_table :municipal_plan_district_assignments do |t|
      t.bigint :municipal_plan_id, null: false
      t.bigint :registered_address_district_id, null: false

      t.timestamps
    end

    add_index :municipal_plan_district_assignments, :municipal_plan_id,
      name: "index_mp_district_assignments_on_plan_id"
    add_index :municipal_plan_district_assignments, :registered_address_district_id,
      name: "index_mp_district_assignments_on_district_id"
    add_index :municipal_plan_district_assignments,
      [:municipal_plan_id, :registered_address_district_id],
      unique: true, name: "index_mp_district_assignments_unique"
  end
end
