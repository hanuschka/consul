class ProjektEvaluations::GenerateProposalPhaseSummary < ApplicationService
  def initialize(phase_stats)
    @phase_stats = phase_stats
  end

  def call
    top_proposals = @phase_stats[:top_proposals] || []
    return nil if top_proposals.empty?

    distribution = analyze_distribution(top_proposals)
    prompt = build_user_prompt(top_proposals, distribution)
    response_text = get_ai_response(prompt)

    parse_response(response_text)
  rescue StandardError => e
    Rails.logger.error("[Evaluation] GenerateProposalPhaseSummary failed: #{e.message}")
    nil
  end

  private

  def target_language
    Rails.env.development? ? "English" : "German"
  end

  def analyze_distribution(proposals)
    support_counts = proposals.map { |p| p[:supports].to_i }
    max_support = support_counts.max
    min_support = support_counts.min
    spread = max_support - min_support
    avg = (support_counts.sum.to_f / support_counts.size).round(1)

    pattern =
      if max_support.zero?
        "no_engagement"
      elsif spread <= max_support * 0.3
        "even_distribution"
      elsif support_counts.count { |c| c >= max_support * 0.7 } <= 2
        "clear_favorites"
      else
        "mixed"
      end

    {
      max_support: max_support,
      min_support: min_support,
      spread: spread,
      average: avg,
      total: support_counts.sum,
      count: support_counts.size,
      pattern: pattern
    }
  end

  def build_user_prompt(proposals, distribution)
    proposals_text = proposals.map do |p|
      "- #{p[:title]} (supports: #{p[:supports]}, rank: #{p[:rank]})"
    end.join("\n")

    <<~TEXT
      Analyze the following citizen proposals and their support counts.

      Distribution stats:
      - Total proposals: #{distribution[:count]}
      - Total supports: #{distribution[:total]}
      - Highest support: #{distribution[:max_support]}
      - Lowest support: #{distribution[:min_support]}
      - Spread: #{distribution[:spread]}
      - Average per proposal: #{distribution[:average]}
      - Pattern: #{distribution[:pattern]}

      Proposals:
      #{proposals_text}
    TEXT
  end

  def get_ai_response(user_prompt)
    response = Ai::RubyLlmFactory
      .chat(feature: "projekt_evaluations.proposal_phase_summary")
      .with_instructions(system_instructions)
      .ask(user_prompt)

    response.content.to_s
  end

  def system_instructions
    <<~TEXT
      You are analyzing citizen participation results for a civic engagement dashboard.

      Return ONLY valid JSON in exactly this shape:
      {"title": "...", "body": "..."}

      TITLE rules:
      - Exactly 3 to 7 words in #{target_language}
      - Captures the main pattern of the distribution
      - Examples: "Strong and even approval", "Clear favorites, large spread", "Low engagement across the board"

      BODY rules:
      - Write 4 to 6 sentences in #{target_language}
      - Open with a bold characterization of the distribution using <strong> tags
      - Name the top 2-3 proposals with their support counts, wrapping the proposal name in <strong> tags — e.g. <strong>Barren/Stufenbarren</strong> (32)
      - Identify notable middle or lower performers
      - If there is a clear outlier (unusually low or high), mention it and hypothesize briefly
      - End with one actionable recommendation sentence
      - Use inline <strong> tags only — no other HTML tags, no markdown
      - Plain prose, no bullet lists

      Do not include any text outside the JSON.
    TEXT
  end

  def parse_response(content)
    cleaned = content.strip.gsub(/^```json\s*/, "").gsub(/\s*```$/, "")
    first_brace = cleaned.index("{")
    last_brace = cleaned.rindex("}")

    return nil if first_brace.nil? || last_brace.nil?

    json_str = cleaned[first_brace..last_brace]
    data = JSON.parse(json_str)

    {
      title: data["title"].to_s.strip,
      body: data["body"].to_s.strip
    }
  rescue JSON::ParserError => e
    Rails.logger.error("[Evaluation] Failed to parse AI response: #{e.message}")
    nil
  end
end
