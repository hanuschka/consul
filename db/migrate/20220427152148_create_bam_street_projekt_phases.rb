class CreateBamStreetProjektPhases < ActiveRecord::Migration[5.2]
  def change
    create_table :bam_street_projekt_phases do |t|
      t.references :bam_street, foreign_key: true
      t.references :projekt_phase, foreign_key: true

      t.timestamps
    end
  end
end
