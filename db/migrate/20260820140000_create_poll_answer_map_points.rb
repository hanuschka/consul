class CreatePollAnswerMapPoints < ActiveRecord::Migration[6.1]
  def change
    create_table :poll_answer_map_points do |t|
      t.references :poll_answer, null: false, foreign_key: { on_delete: :cascade }
      t.float :latitude, null: false
      t.float :longitude, null: false

      t.timestamps
    end
  end
end
