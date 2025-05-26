class AddIdeaOfficerToIdeas < ActiveRecord::Migration[6.1]
  def change
    add_reference :ideas, :idea_officer, foreign_key: { to_table: :idea_officers }, index: true

    reversible do |dir|
      dir.up do
        Idea.add_translation_fields! official_answer: :text
      end

      dir.down do
        remove_column :idea_translations, :official_answer
      end
    end
  end
end
