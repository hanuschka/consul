class CreatePointOfInteresets < ActiveRecord::Migration[6.1]
  def change
    create_table :projekt_point_of_interest_pins do |t|
      t.references :projekt_phase, null: false, index: true
      t.integer :projekt_point_of_interest_category_id
      t.references :author, index: true

      t.timestamps
    end

    add_index :projekt_point_of_interest_pins, :projekt_point_of_interest_category_id, name: "projekt_point_of_interest_category"

    create_table :projekt_point_of_interest_categories do |t|
      t.references :projekt_phase, null: false
      t.string :name, null: false
      t.string :color, null: false
      t.string :icon, null: false
      t.integer :position, default: 0

      t.timestamps
    end

    add_reference :map_locations, :mappable, polymorphic: true, index: true
  end
end
