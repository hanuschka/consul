class AddMasterportalCollectionToMasterportalPins < ActiveRecord::Migration[6.1]
  def change
    add_reference :masterportal_pins, :masterportal_collection,
                  null: true, foreign_key: true, index: true
  end
end
