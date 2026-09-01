class AddUniqueIndexOnMapPointAnswers < ActiveRecord::Migration[6.1]
  def change
    add_index :poll_answers, [:question_id, :author_id],
              unique: true,
              where: "answer IS NULL",
              name: "index_poll_answers_unique_map_point_answer"
  end
end
