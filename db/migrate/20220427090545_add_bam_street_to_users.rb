class AddBamStreetToUsers < ActiveRecord::Migration[5.2]
  def change
    add_reference :users, :bam_street, foreign_key: true
  end
end
