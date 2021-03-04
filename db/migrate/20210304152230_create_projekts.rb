class CreateProjekts < ActiveRecord::Migration[5.1]
  def change
    create_table :projekts do |t|
      t.string :name
      t.references :parent, foreign_key: { to_table: :projekts }

      t.timestamps
    end
  end
end
