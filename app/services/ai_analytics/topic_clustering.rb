class AiAnalytics::TopicClustering < ApplicationService
  attr_reader :projekt_phase

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def call
    Rails.logger.info("[AI Analytics] TopicClustering: start for projekt_phase ##{projekt_phase.id}")
    resources = AiAnalytics::ClusteringCore.get_resources(projekt_phase)

    if resources.empty?
      Rails.logger.info("[AI Analytics] TopicClustering: No resources found for projekt_phase ##{projekt_phase.id}")
      return []
    end

    Rails.logger.info("[AI Analytics] TopicClustering: Starting clustering for #{resources.count} resources (projekt_phase ##{projekt_phase.id})")
    result = generate_clustering(resources)
    Rails.logger.info("[AI Analytics] TopicClustering: Successfully generated clustering for projekt_phase ##{projekt_phase.id}")
    result
  end

  private

    def generate_clustering(resources)
      resource_type = AiAnalytics::ClusteringCore.resource_type_name(resources)
      resources_text = AiAnalytics::ClusteringCore.prepare_resources_data(resources)

      fetched_prompt = fetch_prompt

      system_instructions = <<~TEXT
        #{fetched_prompt}
        Write all topic and subtopic names in #{AiAnalytics::ClusteringCore.target_language}.
      TEXT

      user_prompt = <<~TEXT
        #{resource_type.capitalize}:
        #{resources_text}
      TEXT

      response =
        Ai::RubyLlmFactory
          .chat_with_json_output(AiAnalytics::ClusteringCore.output_schema,
                                 feature: "ai_analytics.topic_clustering")
          .with_instructions(system_instructions)
          .ask(user_prompt)

      response.content["topics"]
    rescue StandardError => e
      Rails.logger.error("TopicClustering error: #{e.message}")
      []
    end

    def fetch_prompt
      parsed_response =
        DtApi::Client.new(use_cache: true).consul_ai_prompts.get(
          :ai_analytics_topic_clustering,
          resource_type: "projekt_phase"
        ).parsed_response
      parsed_response.dig("consul_ai_prompt", "prompt")
    end
end
