class AiStats::SemanticClusteringComponent < ApplicationComponent
  delegate :render?, to: :categories_component

  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def categories_component
    @categories_component ||= AiStats::CategoriesClusteringComponent.new(
      clustering_data: clustering_data,
      title_key: "custom.ai_stats.semantic_clustering",
      resource_class: resource_class
    )
  end

  private

    def clustering_data
      @projekt_phase.ai_stats&.dig("semantic_clustering") || {}
    end

    def resource_class
      case @projekt_phase
      when ProjektPhase::BudgetPhase
        Budget::Investment
      else
        Proposal
      end
    end
end

