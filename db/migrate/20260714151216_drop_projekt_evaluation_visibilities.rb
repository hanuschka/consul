class DropProjektEvaluationVisibilities < ActiveRecord::Migration[6.1]
  def up
    drop_table :projekt_evaluation_visibilities
  end

  def down
    create_table :projekt_evaluation_visibilities do |t|
      t.references :projekt, null: false, index: { unique: true }

      t.boolean "show_project_summary", default: false, null: false
      t.boolean "show_settings", default: false, null: false
      t.boolean "show_phase_summaries", default: false, null: false

      t.timestamps
    end
  end
end
