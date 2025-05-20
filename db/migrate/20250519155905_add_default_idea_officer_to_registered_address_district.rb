class AddDefaultIdeaOfficerToRegisteredAddressDistrict < ActiveRecord::Migration[6.1]
  def change
    add_reference :registered_address_districts, :idea_officer, foreign_key: true, index: true
  end
end
