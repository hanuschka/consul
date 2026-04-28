class ParticapationStats::TopicClusteringComponent < ApplicationComponent
  delegate :render?, to: :categories_component

  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def categories_component
    @categories_component ||= AiStats::CategoriesClusteringComponent.new(
      clustering_data: clustering_data,
      title_key: "custom.ai_stats.topic_clustering",
      resource_class: resource_class
    )
  end

  def show_export_buttons?
    categories.any?
  end

  private

    def categories
      return clustering_data if clustering_data.is_a?(Array)
      clustering_data.values
    end

    def clustering_data
      @projekt_phase.ai_stats&.dig("topic_clustering") || {}
    end

    def resource_class
      case @projekt_phase
      when ProjektPhase::BudgetPhase
        Budget::Investment
      when ProjektPhase::CommentPhase
        Comment
      else
        Proposal
      end
    end
end
