class MoveDataFromBamUniqueStampToUniqueStamp < ActiveRecord::Migration[5.2]
  def up
    # connect users to city streets
    execute "UPDATE users SET unique_stamp = LOWER(bam_unique_stamp)"
  end

  def down
  end
end
