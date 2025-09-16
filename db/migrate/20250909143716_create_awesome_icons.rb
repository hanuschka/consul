class CreateAwesomeIcons < ActiveRecord::Migration[6.1]
  def change
    create_table :awesome_icons do |t|
      t.string :name, null: false
      t.string :unicode, null: false
      t.boolean :shortlisted, default: false, null: false

      t.timestamps
    end

    add_index :awesome_icons, :name, unique: true
  end
end
