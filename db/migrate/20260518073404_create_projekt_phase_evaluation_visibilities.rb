class CreateProjektPhaseEvaluationVisibilities < ActiveRecord::Migration[6.1]
  SECTION_KEYS = %w[
    kpis
    key_metrics
    phase_summary
    tone
    ranking
    proposals
    ai_summary
    timeline
    label_sentiment
    user_segments
    key_findings
    topic_clustering
    semantic_clustering
    ai_questions
    questions
    open_responses
  ].freeze

  def change
    create_table :projekt_phase_evaluation_visibilities do |t|
      t.references :projekt_phase, null: false, index: { unique: true }

      SECTION_KEYS.each do |key|
        t.boolean "show_#{key}", default: false, null: false
      end

      t.timestamps
    end
  end
end
