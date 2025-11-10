class AddTerminatesPollToPollQuestionAnswer < ActiveRecord::Migration[6.1]
  def change
    add_column :poll_question_answers, :terminates_poll, :boolean, default: false, null: false
  end
end
