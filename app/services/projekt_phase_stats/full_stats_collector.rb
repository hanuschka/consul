class ProjektPhaseStats::FullStatsCollector < ApplicationService
  SUPPORTED_PHASES = [
    ProjektPhase::ProposalPhase,
    ProjektPhase::BudgetPhase,
    ProjektPhase::CommentPhase
  ].freeze

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def call
    return {} unless supported?

    {
      label_sentiment: safely { ProjektPhaseStats::LabelSentimentQuery.call(@projekt_phase) },
      timeline: safely { ProjektPhaseStats::TimelineQuery.call(@projekt_phase) },
      user_segments: safely { ProjektPhaseStats::UserSegmentsQuery.call(@projekt_phase) },
      heatmap: safely { ProjektPhaseStats::HeatmapQuery.call(@projekt_phase) },
      participations: participations_list
    }
  end

  private

    def supported?
      SUPPORTED_PHASES.any? { |klass| @projekt_phase.is_a?(klass) }
    end

    def safely
      yield
    rescue StandardError => e
      Rails.logger.warn("[FullStatsCollector] section failed for phase ##{@projekt_phase.id}: #{e.message}")
      nil
    end

    def participations_list
      return [] if @projekt_phase.is_a?(ProjektPhase::CommentPhase)
      return [] if !@projekt_phase.respond_to?(:participations)

      Array(@projekt_phase.participations)
    end
end
