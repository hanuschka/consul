class AddBamUniqueStampToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :bam_unique_stamp, :string
  end
end
