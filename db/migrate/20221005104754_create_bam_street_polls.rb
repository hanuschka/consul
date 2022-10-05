class CreateBamStreetPolls < ActiveRecord::Migration[5.2]
  def change
    create_table :bam_street_polls do |t|
      t.references :bam_street, foreign_key: true
      t.references :poll, foreign_key: true

      t.timestamps
    end
  end
end
