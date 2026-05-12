class AddMasterportalPinIdToProjektPointOfInterestPins < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_point_of_interest_pins, :masterportal_pin_id, :bigint
    add_index :projekt_point_of_interest_pins, :masterportal_pin_id
  end
end
