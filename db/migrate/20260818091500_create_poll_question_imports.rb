class CreatePollQuestionImports < ActiveRecord::Migration[6.1]
  def change
    create_table :poll_question_imports do |t|
      t.integer :projekt_phase_id
      t.integer :author_id
      t.text :extracted_text
      t.string :content_locale
      t.string :status, default: "pending", null: false
      t.jsonb :result
      t.jsonb :created_question_ids, default: []
      t.text :error_message

      t.timestamps
    end

    add_index :poll_question_imports, [:projekt_phase_id, :status]
    add_index :poll_question_imports, :author_id
  end
end
