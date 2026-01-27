class AiAnalytics::GenerateAllStats < ApplicationService
  attr_reader :projekt_phase

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def call
    resources = get_resources

    if resources.empty?
      Rails.logger.info("[AI Analytics] GenerateAllStats: No resources found for projekt_phase ##{projekt_phase.id}")
      return {}
    end

    Rails.logger.info("[AI Analytics] GenerateAllStats: Starting analysis for #{resources.count} resources (projekt_phase ##{projekt_phase.id})")

    summary_stats = AiAnalytics::ProjektPhaseSummary.call(projekt_phase)

    result = {
      summary: summary_stats[:summary],
      tone_of_participation: summary_stats[:tone_of_participation]
    }

    unless projekt_phase.is_a?(ProjektPhase::CommentPhase)
      result[:tone_of_comments] = summary_stats[:tone_of_comments]
      result[:topic_clustering] = generate_topic_clustering
      result[:semantic_clustering] = generate_semantic_clustering
    end

    result.tap do
      Rails.logger.info("[AI Analytics] GenerateAllStats: Successfully completed analysis for projekt_phase ##{projekt_phase.id}")
    end
  end

  private

    def get_resources
      case projekt_phase
      when ProjektPhase::ProposalPhase
        projekt_phase.resources.base_selection.includes(:author, comments: :user)
      when ProjektPhase::BudgetPhase
        return [] unless projekt_phase.budget

        projekt_phase.budget.investments.includes(:author, comments: :user)
      when ProjektPhase::CommentPhase
        projekt_phase.comments.includes(:user)
      else
        []
      end
    end

    def generate_topic_clustering
      AiAnalytics::TopicClustering.call(projekt_phase)
    end

    def generate_semantic_clustering
      AiAnalytics::SemanticClustering.call(projekt_phase)
    end
end
