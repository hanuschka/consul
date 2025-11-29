class AiAnalytics::ProjektPhaseSummary < ApplicationService
  attr_reader :projekt_phase

  def initialize(projekt_phase)
    @projekt_phase = projekt_phase
  end

  def call
    return {} unless projekt_phase.respond_to?(:resources)

    resources = projekt_phase.resources.includes(:author, comments: :user)
    return {} if resources.empty?

    {
      summary: generate_summary(resources),
      tone_of_participation: generate_tone_of_participation(resources),
      tone_of_comments: generate_tone_of_comments(resources)
    }
  end

  private

  def generate_summary(resources)
    proposals_text = resources.map do |proposal|
      "Title: #{proposal.title}. Description: #{proposal.description&.truncate(200)}"
    end.join("\n")

    prompt = <<~TEXT
      Create a concise, neutral and fluent prose summary of the provided list of proposals in 5–7 sentences. Focus on identifying the main recurring themes and cluster similar proposals into meaningful categories (such as support services, physical activity, community life, culture or education). Describe the central trends and dominant topics without listing individual proposals. Avoid bullet points and write a coherent, well-structured text. Ensure that the summary gives project managers a quick and accurate overview of the overall situation.

      Proposals:
      #{proposals_text}
    TEXT

    get_ai_response(prompt)
  end

  def generate_tone_of_participation(resources)
    proposals_text = resources.map do |proposal|
      "#{proposal.title}. #{proposal.description&.truncate(150)}"
    end.join("\n")

    prompt = <<~TEXT
      Identify the overall tone of the following proposal and express it in exactly two words. Use broad, descriptive terms (e.g., "positive supportive", "critical concerned", "neutral informative"). Do not explain your choice and do not add additional text. Output only the two words.

      Proposals:
      #{proposals_text}
    TEXT

    get_ai_response(prompt)
  end

  def generate_tone_of_comments(resources)
    comments = resources.flat_map(&:comments)
    return nil if comments.empty?

    comments_text =
      comments
        .map { |c| c.body&.truncate(150) }
        .compact
        .join("\n")

    return nil if comments_text.blank?

    prompt = <<~TEXT
      Identify the overall tone of the following comments in proposals and express it in exactly two words. Use broad, descriptive terms (e.g., "positive supportive", "critical concerned", "neutral informative"). Do not explain your choice and do not add additional text. Output only the two words.

      Comments:
      #{comments_text}
    TEXT

    get_ai_response(prompt)
  end

  def get_ai_response(prompt)
    response = Ai::RubyLlmFactory.chat.ask(prompt)
    response.content.strip
  end
end
