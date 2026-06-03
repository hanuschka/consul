class CreateProjektEvaluationVisibilities < ActiveRecord::Migration[6.1]
  REPORT_SECTION_KEYS = %w[
    project_summary
    settings
    phase_summaries
  ].freeze

  def change
    create_table :projekt_evaluation_visibilities do |t|
      t.references :projekt, null: false, index: { unique: true }

      REPORT_SECTION_KEYS.each do |key|
        t.boolean "show_#{key}", default: false, null: false
      end

      t.timestamps
    end
  end
end
