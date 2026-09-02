class AddRandomizePositionToPollQuestions < ActiveRecord::Migration[6.1]
  def change
    add_column :poll_questions, :randomize_position, :boolean, default: false, null: false
  end
end
