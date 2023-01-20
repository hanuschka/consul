class CreateProjektLabels < ActiveRecord::Migration[5.2]
  def change
    create_table :projekt_labels do |t|
      t.string :color
      t.string :icon
      t.references :projekt, foreign_key: true

      t.timestamps
    end
  end
end
