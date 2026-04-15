class Evaluations::GeneratePhaseKeyFindings < ApplicationService
  VALID_SENTIMENTS = %w[negative positive warning primary].freeze

  def initialize(phase)
    @phase = phase
  end

  def call
    return [] if empty_phase?

    prompt = build_user_prompt
    response_text = get_ai_response(prompt)
    parse_response(response_text)
  rescue StandardError => e
    Rails.logger.error("[Evaluation] GeneratePhaseKeyFindings failed for #{phase_type}: #{e.message}")
    []
  end

  private

  def phase_type
    @phase[:phase_type]
  end

  def phase_stats
    @phase[:stats] || {}
  end

  def empty_phase?
    case phase_type
    when "ProjektPhase::ProposalPhase"
      (phase_stats[:top_proposals] || []).empty?
    when "ProjektPhase::VotingPhase"
      (phase_stats[:polls] || []).all? { |p| (p[:questions] || []).empty? }
    when "ProjektPhase::BudgetPhase"
      phase_stats[:investments_count].to_i.zero?
    when "ProjektPhase::CommentPhase"
      phase_stats[:comments_count].to_i.zero?
    else
      true
    end
  end

  def target_language
    Rails.env.development? ? "English" : "German"
  end

  def build_user_prompt
    <<~TEXT
      Phase: "#{@phase[:phase_title]}" (type: #{phase_type.to_s.demodulize})

      Data:
      #{serialize_phase_data}
    TEXT
  end

  def serialize_phase_data
    case phase_type
    when "ProjektPhase::ProposalPhase"
      serialize_proposal_phase
    when "ProjektPhase::VotingPhase"
      serialize_voting_phase
    when "ProjektPhase::BudgetPhase"
      serialize_budget_phase
    when "ProjektPhase::CommentPhase"
      serialize_comment_phase
    else
      ""
    end
  end

  def serialize_proposal_phase
    stats = phase_stats
    top = (stats[:top_proposals] || []).first(10).map do |p|
      "  - rank #{p[:rank]}: #{p[:title]} (#{p[:supports]} supports)"
    end.join("\n")

    <<~TEXT
      Total proposals: #{stats[:proposals_count]}
      Total supports: #{stats[:supports_count]}
      Avg supports per proposal: #{stats[:avg_supports_per_proposal]}
      Unique participants: #{stats[:unique_participants]}

      Top proposals:
      #{top}
    TEXT
  end

  def serialize_voting_phase
    polls = (phase_stats[:polls] || []).reject { |p| (p[:questions] || []).empty? }
    polls_text = polls.map { |poll| serialize_voting_poll(poll) }.join("\n\n")

    <<~TEXT
      Total voters: #{phase_stats[:participants_count]}
      Total questions: #{phase_stats[:questions_count]}
      Open text contributions: #{phase_stats[:open_text_count]}

      Polls:
      #{polls_text}
    TEXT
  end

  def serialize_voting_poll(poll)
    questions_text = (poll[:questions] || []).map { |q| serialize_voting_question(q) }.join("\n")
    "Poll: \"#{poll[:name]}\" (#{poll[:voters_count]} voters)\n#{questions_text}"
  end

  def serialize_voting_question(question)
    answers = (question[:answers] || []).map do |a|
      "    #{a[:title]}: #{a[:count]} (#{a[:percentage]}%)"
    end.join("\n")

    "- Q \"#{question[:title]}\" [#{question[:vote_type]}]\n#{answers}"
  end

  def serialize_budget_phase
    <<~TEXT
      Investments: #{phase_stats[:investments_count]}
      Supports: #{phase_stats[:supports_count]}
      Participants: #{phase_stats[:unique_participants]}
      Heading price: #{phase_stats[:heading_price]} #{phase_stats[:currency_symbol]}
    TEXT
  end

  def serialize_comment_phase
    <<~TEXT
      Comments: #{phase_stats[:comments_count]}
      Unique commenters: #{phase_stats[:unique_commenters]}
    TEXT
  end

  def get_ai_response(user_prompt)
    response = Ai::RubyLlmFactory
      .chat
      .with_instructions(system_instructions)
      .ask(user_prompt)

    response.content.to_s
  end

  def system_instructions
    <<~TEXT
      You are generating "Key Findings" for a single phase of a citizen participation project.

      Return ONLY valid JSON in exactly this shape:
      {
        "findings": [
          {"label": "Kernaussage", "title": "...", "body": "...", "sentiment": "..."},
          {"label": "Konsens", "title": "...", "body": "...", "sentiment": "..."},
          {"label": "Ursache", "title": "...", "body": "...", "sentiment": "..."},
          {"label": "Emotion", "title": "...", "body": "...", "sentiment": "..."}
        ]
      }

      FOUR FINDINGS scoped to THIS phase only — one per label. Do not change the labels.

      - Kernaussage: the core headline finding from this phase (often a conflict or standout result)
      - Konsens: where participants broadly agreed within this phase
      - Ursache: the main driver or cause behind the phase's pattern
      - Emotion: the most emotionally charged or divisive topic within this phase

      Each finding must have:
      - title: 3 to 8 words in #{target_language}
      - body: 1 to 3 sentences in #{target_language}, citing specific numbers in <strong> tags
      - sentiment: one of "negative", "positive", "warning", "primary"
        - negative for rejections or controversies
        - positive for broad support or consensus
        - warning for causes or concerns
        - primary for emotional or neutral observations

      Use inline <strong> tags only, no other HTML, no markdown.
      Do not include any text outside the JSON.
    TEXT
  end

  def parse_response(content)
    cleaned = content.strip.gsub(/^```json\s*/, "").gsub(/\s*```$/, "")
    first_brace = cleaned.index("{")
    last_brace = cleaned.rindex("}")

    return [] if first_brace.nil? || last_brace.nil?

    json_str = cleaned[first_brace..last_brace]
    data = JSON.parse(json_str)
    findings = data["findings"]

    return [] if findings.nil? || !findings.is_a?(Array)

    findings.map do |f|
      sentiment = f["sentiment"].to_s
      sentiment = "primary" unless VALID_SENTIMENTS.include?(sentiment)

      {
        label: f["label"].to_s.strip,
        title: f["title"].to_s.strip,
        body: f["body"].to_s.strip,
        sentiment: sentiment
      }
    end
  rescue JSON::ParserError => e
    Rails.logger.error("[Evaluation] Failed to parse phase key findings: #{e.message}")
    []
  end
end
