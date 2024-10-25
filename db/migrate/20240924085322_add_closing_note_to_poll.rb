class AddClosingNoteToPoll < ActiveRecord::Migration[6.1]
  def change
    reversible do |dir|
      dir.up do
        Poll.add_translation_fields! closing_note: :text
      end

      dir.down do
        remove_column :poll_translations, :closing_note
      end
    end
  end
end
