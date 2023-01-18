class MoveDataFromBamStreetToCityStreet < ActiveRecord::Migration[5.2]
  def up
    # connect users to city streets
    execute "UPDATE users SET city_street_id = bam_street_id"
  end

  def down
  end
end
