class CreateProjektEvaluations < ActiveRecord::Migration[6.1]
  def change
    create_table :projekt_evaluations do |t|
      t.references :projekt, null: false, foreign_key: true, index: true
      t.jsonb :data, default: {}
      t.jsonb :selected_question_ids, default: []
      t.datetime :generated_at
      t.string :share_token
      t.string :status, default: "pending", null: false

      t.timestamps
    end

    add_index :projekt_evaluations, :share_token, unique: true
    add_index :projekt_evaluations, :status
  end
end
