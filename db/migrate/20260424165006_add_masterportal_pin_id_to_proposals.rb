class AddMasterportalPinIdToProposals < ActiveRecord::Migration[6.1]
  def change
    add_column :proposals, :masterportal_pin_id, :bigint
    add_index :proposals, :masterportal_pin_id
  end
end
