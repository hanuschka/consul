class AddContextedCloneOfToPollQuestions < ActiveRecord::Migration[6.1]
  def change
    add_reference :poll_questions, :contexted_clone_of_poll_question, foreign_key: { to_table: :poll_questions }, index: true
    add_reference :poll_questions, :context, foreign_key: { to_table: :poll_question_answers }, index: true
  end
end
