class ProjektEvaluations::GeneratePhaseKeyFindings < ApplicationService
  include Rails.application.routes.url_helpers

  VALID_SENTIMENTS = %w[negative positive warning primary].freeze
  VALID_TYPES = %w[comment question proposal investment].freeze
  MAX_REFS_PER_FINDING = 3
  MAX_COMMENTS_IN_PROMPT = 30
  MAX_REF_SNIPPET = 180

  def initialize(phase, projekt_phase:)
    @phase = phase
    @projekt_phase = projekt_phase
  end

  def call
    return [] if empty_phase?

    response_data = get_ai_response(build_user_prompt)
    parse_response(response_data)
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

  def top_investments
    stat_value(:top_investments) || []
  end

  def top_comments
    stat_value(:top_comments) || []
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
    investments_text = top_investments.first(15).map do |i|
      id = i[:id] || i["id"]
      title = i[:title] || i["title"]
      supports = i[:supports] || i["supports"]
      winner = i[:winner] || i["winner"]
      "  - investment id=#{id}: \"#{title}\" (#{supports} supports)#{winner ? " [winner]" : ""}"
    end.join("\n")

    <<~TEXT
      Investments: #{stat_value(:investments_count)}
      Supports: #{stat_value(:supports_count)}
      Participants: #{stat_value(:unique_participants)}

      Investments:
      #{investments_text}
    TEXT
  end

  def serialize_comment_phase
    comments_text = top_comments.first(MAX_COMMENTS_IN_PROMPT).map do |c|
      id = c[:id] || c["id"]
      body = (c[:body] || c["body"]).to_s.gsub(/\s+/, " ").truncate(300)
      "  - comment id=#{id}: \"#{body}\""
    end.join("\n")

    <<~TEXT
      Comments: #{stat_value(:comments_count)}
      Unique commenters: #{stat_value(:unique_commenters)}

      Comments:
      #{comments_text}
    TEXT
  end

  def get_ai_response(user_prompt)
    response = Ai::RubyLlmFactory
      .chat(feature: "projekt_evaluations.phase_key_findings")
      .with_schema(output_schema)
      .with_instructions(Ai::EvaluationContext.prepend_to(system_instructions, @projekt_phase))
      .ask(user_prompt)

    response.content
  end

  def output_schema
    {
      type: "object",
      additionalProperties: false,
      properties: {
        findings: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            properties: {
              label: { type: "string", description: "1-3 word theme derived from the finding, in the target language" },
              title: { type: "string", description: "3-8 word headline in the target language" },
              body: { type: "string", description: "1-3 sentences; numbers in <strong> tags; inline [1],[2] citations" },
              sentiment: { type: "string", enum: VALID_SENTIMENTS },
              references: {
                type: "array",
                items: {
                  type: "object",
                  additionalProperties: false,
                  properties: {
                    type: { type: "string", enum: VALID_TYPES },
                    id: { type: "integer", description: "exact integer id from the provided data" },
                    poll_id: { type: "integer", description: "poll id for comment/question refs in voting phases, otherwise 0" },
                    snippet: { type: "string" }
                  },
                  required: %w[type id poll_id snippet]
                }
              }
            },
            required: %w[label title body sentiment references]
          }
        }
      },
      required: %w[findings]
    }
  end

  def system_instructions
    <<~TEXT
      You are generating "Key Findings" for a single phase of a citizen participation project.

      Produce EXACTLY FOUR findings, derived from the data itself: the four most
      important and distinct insights — do NOT force fixed categories. Order them
      from most to least important.

      EACH FINDING:
      - label: a 1-3 word theme in #{target_language} that you derive from the
        finding's content (the topic, tension, or driver it captures)
      - title: 3-8 words in #{target_language}
      - body: 1-3 sentences in #{target_language}. Put numbers in <strong> tags,
        use inline <strong> only (no other HTML, no markdown), and mark citations
        inline with [1], [2], [3] matching the references indices of THAT finding.
        Example: "68,5% lehnen ab[1]. Parken ist emotional[2]."
      - sentiment: one of #{VALID_SENTIMENTS.join(", ")}.
      - references: 1 to #{MAX_REFS_PER_FINDING} items, each drawn DIRECTLY from
        the provided data.
        - id: the exact integer id from the data (e.g. comment id=501 → 501)
        - poll_id: for comment/question references in voting phases use the
          poll_id from the data ("poll_id=X"); otherwise 0.
        - snippet: verbatim quote or formatted label (<=150 chars). For questions,
          use "title → winning answer (pct%)".
    TEXT
  end

  def parse_response(content)
    data = content.is_a?(String) ? JSON.parse(content) : content
    return [] unless data.is_a?(Hash)

    findings = data["findings"] || data[:findings]
    return [] unless findings.is_a?(Array)

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
      if poll_id.present? && !poll_id.zero?
        poll_path(poll_id, anchor: "comment_#{id}")
      else
        comment_phase_comment_path(id)
      end
    when "investment"
      budget_id = Budget::Investment.where(id: id).pick(:budget_id)
      return nil if budget_id.nil?

      budget_investment_path(budget_id, id)
    end
  rescue StandardError => e
    Rails.logger.warn("[Evaluation] URL resolution failed for #{type}##{id}: #{e.message}")
    nil
  end

  def comment_phase_comment_path(comment_id)
    return nil if phase_page_slug.blank?

    page_path(phase_page_slug, projekt_phase_id: phase_id_value, anchor: "comment_#{comment_id}")
  end

  def phase_id_value
    @phase[:phase_id] || @phase["phase_id"]
  end

  def phase_page_slug
    return @phase_page_slug if defined?(@phase_page_slug)

    projekt_phase = ProjektPhase.find_by(id: phase_id_value)
    @phase_page_slug = projekt_phase&.projekt&.page&.slug
  end
end
