class MoveRatingScaleLabelsFromPollQuestionToVotationType < ActiveRecord::Migration[6.1]
  def up
    transaction do
      VotationType.create_translation_table! min_rating_scale_label: :string, max_rating_scale_label: :string

      execute <<~SQL.squish
        INSERT INTO votation_type_translations (votation_type_id, locale, min_rating_scale_label, max_rating_scale_label, created_at, updated_at)
        SELECT votation_types.id, poll_question_translations.locale, poll_question_translations.min_rating_scale_label, poll_question_translations.max_rating_scale_label, NOW(), NOW()
        FROM poll_question_translations
        JOIN votation_types
        ON votation_types.questionable_id = poll_question_translations.poll_question_id
        AND votation_types.questionable_type = 'Poll::Question'
      SQL
    end
  end

  def down
    VotationType.drop_translation_table!
  end
end
