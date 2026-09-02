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

    Rails.logger.info("[AI Analytics] ProjektPhaseSummary: Starting summary generation for #{resources.count} resources (projekt_phase ##{projekt_phase.id})")

    result = {
      summary: generate_summary(resources),
      tone_of_participation: generate_tone_of_participation(resources)
    }

    unless projekt_phase.is_a?(ProjektPhase::CommentPhase)
      result[:tone_of_comments] = generate_tone_of_comments(resources)
    end

    result.tap do
      Rails.logger.info("[AI Analytics] ProjektPhaseSummary: Successfully completed summary generation for projekt_phase ##{projekt_phase.id}")
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
      when ProjektPhase::CommentPhase
        projekt_phase.comments.includes(:user)
      else
        []
      end
    end

    def resource_type_name(resources)
      return "proposals" if resources.empty?

      if resources.first.is_a?(Budget::Investment)
        "investments"
      elsif resources.first.is_a?(Comment)
        "comments"
      else
        "proposals"
      end
    end

    def generate_summary(resources)
      resource_type = resource_type_name(resources)
      items_text = resources.map do |item|
        if item.is_a?(Comment)
          item.body&.truncate(300)
        else
          "Title: #{item.title}. Description: #{item.description&.truncate(200)}"
        end
      end.join("\n")

      system_instructions = <<~TEXT
        Create a concise, neutral and fluent prose summary of the provided list of #{resource_type} in 2–3 sentences.
        Focus on identifying the main recurring themes and cluster similar #{resource_type} into meaningful categories
        (such as support services, physical activity, community life, culture or education).
        Describe the central trends and dominant topics without listing individual #{resource_type}.
        Avoid bullet points and write a coherent, well-structured text.
        Ensure that the summary gives project managers a quick and accurate overview of the overall situation.
        Write the summary in #{target_language}.
      TEXT

      user_prompt = "#{resource_type.capitalize}:\n#{items_text}"

      get_ai_response(system_instructions, user_prompt)
    end

    def generate_tone_of_participation(resources)
      resource_type = resource_type_name(resources)
      items_text = resources.map do |item|
        if item.is_a?(Comment)
          item.body&.truncate(200)
        else
          "#{item.title}. #{item.description&.truncate(150)}"
        end
      end.join("\n")

      system_instructions = <<~TEXT
        Identify the overall tone of the following #{resource_type} and express it in exactly two words in #{target_language}.
        Use broad, descriptive terms (for intance: "positive supportive", "critical concerned", "neutral informative"), but you can create your own terms.
        Do not explain your choice and do not add additional text. Output only the two words.
      TEXT

      user_prompt = "#{resource_type.capitalize}:\n#{items_text}"

      get_ai_response(system_instructions, user_prompt)
    end

    def generate_tone_of_comments(resources)
      comments = if resources.first&.is_a?(Comment)
                   resources
                 elsif resources.first&.is_a?(Budget::Investment)
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

      system_instructions = <<~TEXT
        Identify the overall tone of the following comments in #{resource_type} and express it in exactly two words in #{target_language}.
        Use broad, descriptive terms (for instance: "positive supportive", "critical concerned", "neutral informative"), but you can make your own terms.
        Do not explain your choice and do not add additional text.
        Output only the two words.
      TEXT

      user_prompt = "Comments:\n#{comments_text}"

      get_ai_response(system_instructions, user_prompt)
    end

    def get_ai_response(system_instructions, user_prompt)
      response = Ai::RubyLlmFactory.chat(feature: "ai_analytics.phase_summary")
        .with_instructions(Ai::EvaluationContext.prepend_to(system_instructions, projekt_phase))
        .ask(user_prompt)
      response.content.strip
    end
end
