class AddIndexOnParentQuestionIdToPollQuestions < ActiveRecord::Migration[6.1]
  def change
    add_index :poll_questions, :parent_question_id
  end
end
