class CreateMunicipalPlanOfficers < ActiveRecord::Migration[6.1]
  def change
    create_table :municipal_plan_officers do |t|
      t.bigint :user_id

      t.timestamps
    end

    add_index :municipal_plan_officers, :user_id

    create_table :municipal_plan_officer_groups do |t|
      t.string :name
      t.string :default_email

      t.timestamps
    end

    create_table :municipal_plan_officer_group_assignments do |t|
      t.bigint :municipal_plan_officer_id, null: false
      t.bigint :municipal_plan_officer_group_id, null: false

      t.timestamps
    end

    add_index :municipal_plan_officer_group_assignments, :municipal_plan_officer_id,
      name: "index_mp_officer_group_assignments_on_officer_id"
    add_index :municipal_plan_officer_group_assignments, :municipal_plan_officer_group_id,
      name: "index_mp_officer_group_assignments_on_group_id"
    add_index :municipal_plan_officer_group_assignments,
      [:municipal_plan_officer_id, :municipal_plan_officer_group_id],
      unique: true, name: "index_mp_officer_group_assignments_unique"
  end
end
