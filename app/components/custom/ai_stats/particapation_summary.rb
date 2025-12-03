class AiStats::ParticapationSummary < ApplicationComponent
  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
    @ai_stats = projekt_phase.ai_stats || {}
  end

  def ai_summary
    @ai_stats.dig("summary")
  end

  def tone_of_participation
    @ai_stats.dig("tone_of_participation")
  end

  def tone_of_comments
    @ai_stats.dig("tone_of_comments")
  end

  def has_ai_stats?
    ai_summary.present? || tone_of_participation.present? || tone_of_comments.present?
  end
end
