class AddIntroToPollQuestions < ActiveRecord::Migration[6.1]
  def change
    reversible do |dir|
      dir.up do
        Poll::Question.add_translation_fields! intro: :text
      end

      dir.down do
        remove_column :poll_question_translations, :intro
      end
    end
  end
end
