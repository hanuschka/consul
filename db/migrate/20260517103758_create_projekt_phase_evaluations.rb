class CreateProjektPhaseEvaluations < ActiveRecord::Migration[6.1]
  def change
    create_table :projekt_phase_evaluations do |t|
      t.references :projekt_evaluation, null: false, index: true
      t.references :projekt_phase, null: false, index: true
      t.jsonb :data, default: {}
      t.string :status, default: "pending", null: false
      t.datetime :generated_at

      t.text :pdf_formatted_html
      t.string :pdf_formatted_status
      t.datetime :pdf_formatted_at
      t.string :pdf_formatted_data_fingerprint
      t.string :pdf_formatted_error

      t.timestamps
    end

    add_index :projekt_phase_evaluations,
      [:projekt_evaluation_id, :projekt_phase_id],
      unique: true,
      name: "index_projekt_phase_evaluations_on_eval_and_phase"
    add_index :projekt_phase_evaluations, :status
  end
end
