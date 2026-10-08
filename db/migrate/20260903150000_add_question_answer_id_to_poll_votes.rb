class AddQuestionAnswerIdToPollVotes < ActiveRecord::Migration[6.1]
  TABLES = %w[poll_answers poll_partial_results].freeze

  def up
    TABLES.each do |table|
      add_column table, :question_answer_id, :integer
      add_index table, :question_answer_id, name: "index_#{table}_on_question_answer_id"
      add_foreign_key table, :poll_question_answers, column: :question_answer_id, on_delete: :nullify

      execute <<~SQL
        UPDATE #{table} AS votes
        SET question_answer_id = matches.question_answer_id
        FROM (
          SELECT rows.id AS vote_id,
                 min(answers.id) AS question_answer_id,
                 count(DISTINCT answers.id) AS candidates
          FROM #{table} AS rows
          JOIN poll_question_answers AS answers
            ON answers.question_id = rows.question_id
          JOIN poll_question_answer_translations AS titles
            ON titles.poll_question_answer_id = answers.id
           AND titles.title = rows.answer
          WHERE rows.answer IS NOT NULL
          GROUP BY rows.id
        ) AS matches
        WHERE votes.id = matches.vote_id
          AND matches.candidates = 1
      SQL
    end
  end

  def down
    TABLES.each do |table|
      remove_foreign_key table, column: :question_answer_id
      remove_index table, name: "index_#{table}_on_question_answer_id"
      remove_column table, :question_answer_id
    end
  end
end
