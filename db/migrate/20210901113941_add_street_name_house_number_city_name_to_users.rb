class AddStreetNameHouseNumberCityNameToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :street_name, :string
    add_column :users, :house_number, :string
    add_column :users, :city_name, :string
    add_column :users, :bam_letter_verification_code_sent_at, :datetime
  end
end
