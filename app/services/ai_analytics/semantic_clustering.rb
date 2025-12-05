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

      prompt = <<~TEXT
        You are an AI specialized in semantic analysis, topic extraction, and hierarchical clustering.
        Your task is to analyze a list of #{resource_type} and generate a meaningful topic structure.

        Your goals:
        Perform a semantic analysis of all #{resource_type}.

        Identify underlying themes, intentions, target groups, and conceptual similarities.
        Ignore superficial wording; focus on meaning.
        Based on your semantic understanding, create 5–7 high-level TOPICS that best represent the conceptual structure of the data.
        For each topic, create 2–4 SUBTOPICS that capture finer semantic distinctions.
        Assign each item to exactly one subtopic (whichever has the strongest semantic fit).
        Ignore subtopics which dosent have at least one assigned resource.
        Ensure topics and subtopics are: meaningful and human-friendly, non-overlapping , comprehensive (cover everything),
        semantically justified (not based on superficial keywords).
        Dont include resource name in topics and subtopics.

        Write all topic and subtopic names in #{AiAnalytics::ClusteringCore.target_language}.

        #{resource_type.capitalize}:
        #{resources_text}
      TEXT

      response = Ai::RubyLlmFactory.chat_with_json_output(AiAnalytics::ClusteringCore.output_schema).ask(prompt)

      response.content["topics"]
    rescue StandardError => e
      Rails.logger.error("SemanticClustering error: #{e.message}")
      []
    end
end

