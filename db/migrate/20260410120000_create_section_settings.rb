class CreateSectionSettings < ActiveRecord::Migration[6.1]
  def change
    create_table :section_settings do |t|
      t.string :section, null: false
      t.string :intro_text
      t.text :notice_message
      t.boolean :notice_active, default: false, null: false
      t.references :author, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :section_settings, :section, unique: true
  end
end
