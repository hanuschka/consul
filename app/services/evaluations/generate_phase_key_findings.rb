class Evaluations::GeneratePhaseKeyFindings < ApplicationService
  include Rails.application.routes.url_helpers

  VALID_SENTIMENTS = %w[negative positive warning primary].freeze
  VALID_TYPES = %w[comment question proposal investment].freeze
  MAX_REFS_PER_FINDING = 3
  MAX_COMMENTS_IN_PROMPT = 30
  MAX_REF_SNIPPET = 180

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
    @phase[:phase_type] || @phase["phase_type"]
  end

  def phase_title
    @phase[:phase_title] || @phase["phase_title"]
  end

  def phase_stats
    @phase[:stats] || @phase["stats"] || {}
  end

  def stat_value(key)
    phase_stats[key] || phase_stats[key.to_s]
  end

  def empty_phase?
    case phase_type
    when "ProjektPhase::ProposalPhase"
      top_proposals.empty?
    when "ProjektPhase::VotingPhase"
      polls.all? { |p| questions_for(p).empty? }
    when "ProjektPhase::BudgetPhase"
      stat_value(:investments_count).to_i.zero?
    when "ProjektPhase::CommentPhase"
      stat_value(:comments_count).to_i.zero?
    else
      true
    end
  end

  def top_proposals
    stat_value(:top_proposals) || []
  end

  def polls
    stat_value(:polls) || []
  end

  def questions_for(poll)
    poll[:questions] || poll["questions"] || []
  end

  def comments_for(poll)
    poll[:open_text_entries] || poll["open_text_entries"] || []
  end

  def target_language
    Rails.env.development? ? "English" : "German"
  end

  def build_user_prompt
    <<~TEXT
      Phase: "#{phase_title}" (type: #{phase_type.to_s.demodulize})

      Data (each source item includes an id you must cite exactly):
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
    proposals_text = top_proposals.first(10).map do |p|
      rank = p[:rank] || p["rank"]
      title = p[:title] || p["title"]
      supports = p[:supports] || p["supports"]
      id = p[:id] || p["id"]
      "  - proposal id=#{id} rank=#{rank}: \"#{title}\" (#{supports} supports)"
    end.join("\n")

    <<~TEXT
      Total proposals: #{stat_value(:proposals_count)}
      Total supports: #{stat_value(:supports_count)}

      Proposals:
      #{proposals_text}
    TEXT
  end

  def serialize_voting_phase
    polls_text = polls.reject { |p| questions_for(p).empty? }
      .map { |p| serialize_voting_poll(p) }
      .join("\n\n")

    <<~TEXT
      Total voters: #{stat_value(:participants_count)}
      Total questions: #{stat_value(:questions_count)}
      Open text contributions: #{stat_value(:open_text_count)}

      Polls:
      #{polls_text}
    TEXT
  end

  def serialize_voting_poll(poll)
    poll_id = poll[:id] || poll["id"]
    poll_name = poll[:name] || poll["name"]
    voters = poll[:voters_count] || poll["voters_count"]
    questions_text = questions_for(poll).map { |q| serialize_voting_question(q, poll_id) }.join("\n")

    all_comments = comments_for(poll).first(MAX_COMMENTS_IN_PROMPT)
    comments_text = all_comments.map do |c|
      body = (c.is_a?(Hash) ? (c[:body] || c["body"]) : c).to_s.gsub(/\s+/, " ").truncate(200)
      id = c.is_a?(Hash) ? (c[:id] || c["id"]) : nil
      "    - comment id=#{id} poll_id=#{poll_id}: \"#{body}\""
    end.join("\n")

    <<~POLL
      Poll id=#{poll_id} "#{poll_name}" (#{voters} voters):
      #{questions_text}
      Comments:
      #{comments_text}
    POLL
  end

  def serialize_voting_question(question, poll_id)
    qid = question[:id] || question["id"]
    title = question[:title] || question["title"]
    vote_type = question[:vote_type] || question["vote_type"]
    answers = question[:answers] || question["answers"] || []

    answers_text = answers.map do |a|
      "      #{a[:title] || a["title"]}: #{a[:count] || a["count"]} (#{a[:percentage] || a["percentage"]}%)"
    end.join("\n")

    "  - question id=#{qid} poll_id=#{poll_id} [#{vote_type}]: \"#{title}\"\n#{answers_text}"
  end

  def serialize_budget_phase
    <<~TEXT
      Investments: #{stat_value(:investments_count)}
      Supports: #{stat_value(:supports_count)}
      Participants: #{stat_value(:unique_participants)}
    TEXT
  end

  def serialize_comment_phase
    <<~TEXT
      Comments: #{stat_value(:comments_count)}
      Unique commenters: #{stat_value(:unique_commenters)}
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
          {
            "label": "Kernaussage",
            "title": "...",
            "body": "...",
            "sentiment": "...",
            "references": [
              {
                "type": "comment|question|proposal|investment",
                "id": <integer, exactly as shown in the provided data>,
                "poll_id": <integer, required for comment/question in a voting phase>,
                "snippet": "..."
              }
            ]
          },
          {"label": "Konsens", ...},
          {"label": "Ursache", ...},
          {"label": "Emotion", ...}
        ]
      }

      FOUR FINDINGS — one per label. Do not change the labels.

      - Kernaussage: core headline
      - Konsens: point of agreement
      - Ursache: main driver/cause
      - Emotion: emotionally charged topic

      EACH FINDING:
      - title: 3-8 words in #{target_language}
      - body: 1-3 sentences in #{target_language}, numbers in <strong> tags.
        Mark citations inline with [1], [2], [3] matching the references array indices of THAT finding.
        Example: "68,5% lehnen ab[1]. Parken ist emotional[2]."
      - sentiment: "negative" | "positive" | "warning" | "primary"
      - references: 1 to #{MAX_REFS_PER_FINDING} items, each drawn DIRECTLY from the provided data.
        - id: use the exact integer id from the data (e.g. comment id=501 → "id": 501)
        - poll_id: include for comment/question references in voting phases (from "poll_id=X" in the data)
        - snippet: verbatim quote or formatted label (<=150 chars). For questions, use "title → winning answer (pct%)".

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

    findings.map { |f| build_finding(f) }
  rescue JSON::ParserError => e
    Rails.logger.error("[Evaluation] Failed to parse phase key findings: #{e.message}")
    []
  end

  def build_finding(finding)
    sentiment = finding["sentiment"].to_s
    sentiment = "primary" unless VALID_SENTIMENTS.include?(sentiment)

    {
      label: finding["label"].to_s.strip,
      title: finding["title"].to_s.strip,
      body: finding["body"].to_s.strip,
      sentiment: sentiment,
      references: build_references(finding["references"])
    }
  end

  def build_references(raw_refs)
    return [] if raw_refs.nil? || !raw_refs.is_a?(Array)

    raw_refs.first(MAX_REFS_PER_FINDING).filter_map do |r|
      build_single_reference(r)
    end
  end

  def build_single_reference(raw)
    type = raw["type"].to_s.strip
    return nil unless VALID_TYPES.include?(type)

    snippet = raw["snippet"].to_s.strip.truncate(MAX_REF_SNIPPET)
    return nil if snippet.blank?

    id = raw["id"].to_i
    return nil if id.zero?

    poll_id = raw["poll_id"].to_i

    {
      type: type,
      id: id,
      poll_id: poll_id.zero? ? nil : poll_id,
      snippet: snippet,
      url: resolve_url(type, id, poll_id)
    }
  end

  def resolve_url(type, id, poll_id)
    case type
    when "proposal"
      proposal_path(id)
    when "question"
      return nil if poll_id.nil? || poll_id.zero?

      poll_path(poll_id, anchor: "question-#{id}")
    when "comment"
      return nil if poll_id.nil? || poll_id.zero?

      poll_path(poll_id, anchor: "comment_#{id}")
    when "investment"
      nil
    end
  rescue StandardError => e
    Rails.logger.warn("[Evaluation] URL resolution failed for #{type}##{id}: #{e.message}")
    nil
  end
end
