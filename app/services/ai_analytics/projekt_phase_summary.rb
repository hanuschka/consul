class AiAnalytics::ProjektPhaseSummary < ApplicationService
  attr_reader :projekt_phase

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def call
    resources = get_resources

    if resources.empty?
      Rails.logger.info("[AI Analytics] ProjektPhaseSummary: No resources found for projekt_phase ##{projekt_phase.id}")
      return {}
    end

    Rails.logger.info("[AI Analytics] ProjektPhaseSummary: Starting analysis for #{resources.count} resources (projekt_phase ##{projekt_phase.id})")

    {
      summary: generate_summary(resources),
      tone_of_participation: generate_tone_of_participation(resources),
      tone_of_comments: generate_tone_of_comments(resources),
      topic_clustering: generate_topic_clustering,
      semantic_clustering: generate_semantic_clustering
    }.tap do
      Rails.logger.info("[AI Analytics] ProjektPhaseSummary: Successfully completed analysis for projekt_phase ##{projekt_phase.id}")
    end
  end

  private

    def target_language
      Rails.env.development? ? "English" : "German"
    end

    def get_resources
      case projekt_phase
      when ProjektPhase::ProposalPhase
        projekt_phase.resources.base_selection.includes(:author, comments: :user)
      when ProjektPhase::BudgetPhase
        return [] unless projekt_phase.budget

        projekt_phase.budget.investments.includes(:author, comments: :user)
      else
        []
      end
    end

    def resource_type_name(resources)
      return "proposals" if resources.empty?

      resources.first.is_a?(Budget::Investment) ? "investments" : "proposals"
    end

    def generate_summary(resources)
      resource_type = resource_type_name(resources)
      items_text = resources.map do |item|
        "Title: #{item.title}. Description: #{item.description&.truncate(200)}"
      end.join("\n")

      prompt = <<~TEXT
        Create a concise, neutral and fluent prose summary of the provided list of #{resource_type} in 2–3 sentences.
        Focus on identifying the main recurring themes and cluster similar #{resource_type} into meaningful categories
        (such as support services, physical activity, community life, culture or education).
        Describe the central trends and dominant topics without listing individual #{resource_type}.
        Avoid bullet points and write a coherent, well-structured text.
        Ensure that the summary gives project managers a quick and accurate overview of the overall situation.

        Write the summary in #{target_language}.

        #{resource_type.capitalize}:
        #{items_text}
      TEXT

      get_ai_response(prompt)
    end

    def generate_tone_of_participation(resources)
      resource_type = resource_type_name(resources)
      items_text = resources.map do |item|
        "#{item.title}. #{item.description&.truncate(150)}"
      end.join("\n")

      prompt = <<~TEXT
        Identify the overall tone of the following #{resource_type} and express it in exactly two words in #{target_language}.
        Use broad, descriptive terms (for intance: "positive supportive", "critical concerned", "neutral informative"), but you can create your own terms.
        Do not explain your choice and do not add additional text. Output only the two words.

        #{resource_type.capitalize}:
        #{items_text}
      TEXT

      get_ai_response(prompt)
    end

    def generate_tone_of_comments(resources)
      comments = if resources.first&.is_a?(Budget::Investment)
                   resources.flat_map { |r| r.comments.where(valuation: false) }
      else
        resources.flat_map(&:comments)
      end

      return nil if comments.empty?

      comments_text =
        comments
          .map { |c| c.body&.truncate(150) }
          .compact
          .join("\n")

      return nil if comments_text.blank?

      resource_type = resource_type_name(resources)

      prompt = <<~TEXT
        Identify the overall tone of the following comments in #{resource_type} and express it in exactly two words in #{target_language}.
        Use broad, descriptive terms (for instance: "positive supportive", "critical concerned", "neutral informative"), but you can make your own terms.
        Do not explain your choice and do not add additional text.
        Output only the two words.

        Comments:
        #{comments_text}
      TEXT

      get_ai_response(prompt)
    end

    def get_ai_response(prompt)
      response = Ai::RubyLlmFactory.chat.ask(prompt)
      response.content.strip
    end

    def generate_topic_clustering
      AiAnalytics::TopicClustering.call(projekt_phase)
    end

    def generate_semantic_clustering
      AiAnalytics::SemanticClustering.call(projekt_phase)
    end
end
