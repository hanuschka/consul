class DowncaseStreetNumberExtensionInRegisteredAddresses < ActiveRecord::Migration[6.1]
  def up
    execute <<-SQL.squish
      UPDATE registered_addresses
      SET street_number_extension = LOWER(street_number_extension)
    SQL
  end

  def down
  end
end
