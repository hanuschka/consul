class DropSectionSettings < ActiveRecord::Migration[6.1]
  def up
    Setting.add_new_settings

    if table_exists?(:section_settings)
      execute(<<~SQL).each do |row|
        SELECT section, intro_text, notice_message, notice_active
        FROM section_settings
      SQL
        section = row["section"]
        next unless Adm::Section::NAMES.include?(section)

        Setting["adm.#{section}.intro_text"] = row["intro_text"] if row["intro_text"].present?
        Setting["adm.#{section}.notice_message"] = row["notice_message"] if row["notice_message"].present?
        Setting["adm.#{section}.notice_active"] = "active" if row["notice_active"]
      end

      drop_table :section_settings
    end
  end

  def down
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
