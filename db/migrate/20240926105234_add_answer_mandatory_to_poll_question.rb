class AddAnswerMandatoryToPollQuestion < ActiveRecord::Migration[6.1]
  def change
    add_column :poll_questions, :answer_mandatory, :boolean, default: false
  end
end
