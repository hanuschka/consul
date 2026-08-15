class AiUsageRecord < ApplicationRecord
  UNKNOWN_FEATURE = "unknown".freeze

  FEATURES = %w[
    ai_analytics.poll_evaluation
    ai_analytics.poll_report
    ai_analytics.phase_stat_question
    ai_analytics.phase_summary
    ai_analytics.semantic_clustering
    ai_analytics.topic_clustering
    content_blocks.edit
    content_blocks.generate
    content_blocks.generate_with_prompt
    deficiency_reports.categorization
    projekt_evaluations.phase_key_findings
    projekt_evaluations.phase_short_summary
    projekt_evaluations.project_content_summary
    projekt_evaluations.proposal_phase_summary
    projekt_evaluations.voting_phase_summary
    projekt_imports.chat_response
    projekt_imports.process
    projekt_imports.resolve_content_block_html
    projekts.banner_image_prompt
    proposal_ai_draft.evaluate_criteria
    proposal_ai_draft.generate_draft
    proposal_ai_draft.hard_criteria
    proposal_ai_draft.soft_criteria
  ].push(UNKNOWN_FEATURE).freeze

  COUNTER_COLUMNS = %i[
    request_count unpriced_request_count
    input_tokens output_tokens cache_read_tokens cache_write_tokens
    thinking_tokens audio_seconds cost_total
  ].freeze

  validates :period_month, presence: true
  validates :feature, presence: true
  validates :provider, presence: true
  validates :model, presence: true

  scope :for_period, ->(month) { where(period_month: month) }
  scope :since, ->(month) { where(period_month: month..) }

  def self.known_feature(label)
    FEATURES.include?(label.to_s) ? label.to_s : UNKNOWN_FEATURE
  end

  def self.period_month_for(time)
    time.to_date.beginning_of_month
  end

  def self.current_period_month
    period_month_for(Time.current)
  end
end
