class CreateProjektPhaseStatQuestions < ActiveRecord::Migration[6.1]
  def change
    create_table :projekt_phase_stat_questions do |t|
      t.references :projekt_phase, null: false, foreign_key: true
      t.text :question, null: false
      t.text :answer
      t.string :status, default: "pending", null: false

      t.timestamps
    end

    add_index :projekt_phase_stat_questions, [:projekt_phase_id, :created_at], name: "idx_stat_questions_phase_created"
  end
end
