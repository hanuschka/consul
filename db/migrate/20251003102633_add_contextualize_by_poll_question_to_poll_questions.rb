class AddContextualizeByPollQuestionToPollQuestions < ActiveRecord::Migration[6.1]
  def change
    add_reference :poll_questions, :contextualize_by_poll_question, foreign_key: { to_table: :poll_questions }, index: true
  end
end
