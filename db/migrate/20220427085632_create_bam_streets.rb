class CreateBamStreets < ActiveRecord::Migration[5.2]
  def change
    create_table :bam_streets do |t|
      t.string :name
      t.integer :plz

      t.timestamps
    end
  end
end
