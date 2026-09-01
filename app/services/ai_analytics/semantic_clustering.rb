class AiAnalytics::SemanticClustering < ApplicationService
  attr_reader :projekt_phase

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def call
    resources = AiAnalytics::ClusteringCore.get_resources(projekt_phase)
    return [] if resources.empty?

    generate_clustering(resources)
  end

  private

    def generate_clustering(resources)
      resource_type = AiAnalytics::ClusteringCore.resource_type_name(resources)
      resources_text = AiAnalytics::ClusteringCore.prepare_resources_data(resources)

      fetched_prompt = fetch_prompt

      system_instructions = <<~TEXT
        #{fetched_prompt}
        Write all clusters and subcluster names in #{AiAnalytics::ClusteringCore.target_language}.
        Dont return clusters and subclusters, if there no match of #{resource_type.capitalize}.
      TEXT

      user_prompt = <<~TEXT
        #{resource_type.capitalize}:
        #{resources_text}
      TEXT

        # Your goals:
        # Perform a semantic analysis of all #{resource_type}.

        # Identify underlying themes, intentions, target groups, and conceptual similarities.
        # Ignore superficial wording; focus on meaning.
        # Based on your semantic understanding, create 5–7 high-level TOPICS that best represent the conceptual structure of the data.
        # For each topic, create 2–4 SUBTOPICS that capture finer semantic distinctions.
        # Assign each item to exactly one subtopic (whichever has the strongest semantic fit).
        # Ignore subtopics which dosent have at least one assigned resource.
        # Ensure topics and subtopics are: meaningful and human-friendly, non-overlapping , comprehensive (cover everything),
        # semantically justified (not based on superficial keywords).
        # Dont include resource name in topics and subtopics.
      response =
        Ai::RubyLlmFactory
          .chat_with_json_output(AiAnalytics::ClusteringCore.output_schema,
                                 feature: "ai_analytics.semantic_clustering")
          .with_instructions(Ai::EvaluationContext.prepend_to(system_instructions, projekt_phase))
          .ask(user_prompt)

      response.content["topics"]
    rescue StandardError => e
      Rails.logger.error("SemanticClustering error: #{e.message}")
      []
    end

    def fetch_prompt
      parsed_response =
        DtApi::Client.new(use_cache: true).consul_ai_prompts.get(
          :ai_analytics_semantic_clustering,
          resource_type: "projekt_phase"
        ).parsed_response
      parsed_response.dig("consul_ai_prompt", "prompt")
    end
end
