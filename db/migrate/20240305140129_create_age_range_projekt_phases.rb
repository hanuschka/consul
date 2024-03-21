class CreateAgeRangeProjektPhases < ActiveRecord::Migration[6.1]
  def change
    create_table :age_range_projekt_phases do |t|
      t.references :age_range, foreign_key: true
      t.references :projekt_phase, foreign_key: true
      t.string :used_for, null: false

      t.timestamps
    end
  end
end
