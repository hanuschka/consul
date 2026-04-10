class CreateSectionContactPeople < ActiveRecord::Migration[6.1]
  def change
    create_table :section_contact_people do |t|
      t.references :user, null: false, foreign_key: true
      t.string :section, null: false
      t.string :role
      t.string :email
      t.string :phone
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :section_contact_people, [:section, :position]
  end
end
