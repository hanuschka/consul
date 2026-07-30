class ProjektPhaseEvaluationVisibility < ApplicationRecord
  SECTION_KEYS = %w[
    kpis
    key_metrics
    phase_summary
    tone
    ranking
    ai_summary
    timeline
    label_sentiment
    user_segments
    budget_segments
    heatmap
    key_findings
    topic_clustering
    semantic_clustering
    ai_questions
    questions
    open_responses
  ].freeze

  SECTION_COLUMNS = SECTION_KEYS.map { |k| "show_#{k}" }.freeze

  belongs_to :projekt_phase

  validates :projekt_phase, presence: true
  validates :projekt_phase_id, uniqueness: true

  def visible_sections
    SECTION_KEYS.select { |key| self["show_#{key}"] }
  end

  def any_visible?
    SECTION_COLUMNS.any? { |col| self[col] }
  end

  def include_section?(key)
    return false if key.blank?
    return false if !SECTION_KEYS.include?(key.to_s)

    self["show_#{key}"]
  end
end
