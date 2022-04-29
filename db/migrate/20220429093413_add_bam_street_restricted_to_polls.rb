class AddBamStreetRestrictedToPolls < ActiveRecord::Migration[5.2]
  def change
    add_column :polls, :bam_street_restricted, :boolean, default: false
  end
end
