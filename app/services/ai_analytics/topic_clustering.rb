class AiAnalytics::TopicClustering < ApplicationService
  attr_reader :projekt_phase

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def call
    resources = AiAnalytics::ClusteringCore.get_resources(projekt_phase)

    if resources.empty?
      Rails.logger.info("[AI Analytics] TopicClustering: No resources found for projekt_phase ##{projekt_phase.id}")
      return { "topics" => [] }
    end

    Rails.logger.info("[AI Analytics] TopicClustering: Starting clustering for #{resources.count} resources (projekt_phase ##{projekt_phase.id})")
    result = generate_clustering(resources)
    Rails.logger.info("[AI Analytics] TopicClustering: Successfully generated clustering for projekt_phase ##{projekt_phase.id}")
    result
  end

  private

    def generate_clustering(resources)
      resource_type = AiAnalytics::ClusteringCore.resource_type_name(resources)
      resources_text = resources.map do |resource|
        if resource.is_a?(Comment)
          "ID: #{resource.id}, Content: #{resource.body&.truncate(400)}"
        else
          "ID: #{resource.id}, Title: #{resource.title}, Description: #{resource.description&.truncate(300)}"
        end
      end.join("\n\n")

      prompt = <<~TEXT
        You are an AI specialized in semantic clustering and topic modeling.

        Your task is to create a clean and logical categorization system for a list of #{resource_type}.

        What you must do:

        1. Read the full list of #{resource_type} (see below).
        2. Identify patterns, themes and semantic clusters in the #{resource_type}.
        3. Generate 5–7 meaningful TOPICS (your choice — choose what fits the data best).
        4. For each topic, generate 2–4 SUBTOPICS that further structure the content.
        5. Assign every item to exactly one subtopic using its ID.

        Make sure topics and subtopics:
        - are non-overlapping,
        - are easy to understand for non-experts,
        - cover all #{resource_type} without forcing them unnaturally.

        Write all topic and subtopic names in #{AiAnalytics::ClusteringCore.target_language}.

        #{resource_type.capitalize}:
        #{resources_text}
      TEXT

      response = Ai::RubyLlmFactory.chat_with_json_output(AiAnalytics::ClusteringCore.output_schema).ask(prompt)

      response.content
    rescue StandardError => e
      Rails.logger.error("TopicClustering error: #{e.message}")
      { "topics" => [] }
    end
end
