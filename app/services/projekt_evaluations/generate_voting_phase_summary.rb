class ProjektEvaluations::GenerateVotingPhaseSummary < ApplicationService
  def initialize(phase_stats)
    @phase_stats = phase_stats
  end

  def call
    polls = (@phase_stats[:polls] || []).reject { |p| (p[:questions] || []).empty? }
    return nil if polls.empty?

    distribution = analyze_distribution(polls)
    prompt = build_user_prompt(polls, distribution)
    response_text = get_ai_response(prompt)

    parse_response(response_text)
  rescue StandardError => e
    Rails.logger.error("[Evaluation] GenerateVotingPhaseSummary failed: #{e.message}")
    nil
  end

  private

  def target_language
    Rails.env.development? ? "English" : "German"
  end

  def analyze_distribution(polls)
    all_questions = polls.flat_map { |p| p[:questions] || [] }
    total_voters = polls.sum { |p| p[:voters_count].to_i }

    strong_consensus = []
    contested = []
    rating_leans = []

    all_questions.each do |question|
      answers = question[:answers] || []
      next if answers.empty?

      case question[:vote_type]
      when "rating_scale"
        rating_leans << classify_rating(question, answers)
      when "unique", "multiple"
        top = answers.max_by { |a| a[:count].to_i }
        top_pct = top[:percentage].to_f

        if top_pct >= 60
          strong_consensus << { title: question[:title], answer: top[:title], percentage: top_pct }
        elsif top_pct < 40
          contested << { title: question[:title], top_answer: top[:title], top_percentage: top_pct }
        end
      end
    end

    {
      total_voters: total_voters,
      total_questions: all_questions.size,
      strong_consensus_count: strong_consensus.size,
      contested_count: contested.size,
      rating_leans: rating_leans
    }
  end

  def classify_rating(question, answers)
    total = answers.sum { |a| a[:count].to_i }
    return { title: question[:title], lean: "no_votes" } if total.zero?

    weighted = answers.each_with_index.sum do |answer, idx|
      (idx + 1) * answer[:count].to_i
    end
    avg = weighted.to_f / total
    max_scale = answers.size.to_f

    lean =
      if avg > max_scale * 0.6
        "positive"
      elsif avg < max_scale * 0.4
        "negative"
      else
        "neutral"
      end

    { title: question[:title], lean: lean, average: avg.round(2) }
  end

  def build_user_prompt(polls, distribution)
    polls_text = polls.map { |poll| serialize_poll(poll) }.join("\n\n")

    <<~TEXT
      Analyze the following poll results from a citizen participation vote.

      Engagement:
      - Total voters across polls: #{distribution[:total_voters]}
      - Total questions: #{distribution[:total_questions]}
      - Questions with strong majority (>=60%): #{distribution[:strong_consensus_count]}
      - Questions that were contested (top answer <40%): #{distribution[:contested_count]}
      - Rating question leans: #{distribution[:rating_leans].inspect}

      Polls and questions:
      #{polls_text}
    TEXT
  end

  def serialize_poll(poll)
    questions_text = (poll[:questions] || []).map { |q| serialize_question(q) }.join("\n")

    <<~POLL
      Poll: "#{poll[:name]}" (#{poll[:voters_count]} voters)
      #{questions_text}
    POLL
  end

  def serialize_question(question)
    header = "- Q: \"#{question[:title]}\" [#{question[:vote_type]}]"
    answers = (question[:answers] || []).map do |a|
      "    #{a[:title]}: #{a[:count]} (#{a[:percentage]}%)"
    end.join("\n")

    [header, answers].join("\n")
  end

  def get_ai_response(user_prompt)
    response = Ai::RubyLlmFactory
      .chat(feature: "projekt_evaluations.voting_phase_summary")
      .with_instructions(system_instructions)
      .ask(user_prompt)

    response.content.to_s
  end

  def system_instructions
    <<~TEXT
      You are analyzing poll results from a citizen participation vote for a civic engagement dashboard.

      Return ONLY valid JSON in exactly this shape:
      {"title": "...", "body": "..."}

      TITLE rules:
      - Exactly 3 to 7 words in #{target_language}
      - Captures the main finding of the vote
      - Examples: "Clear support for pedestrian priorities", "Parking divides the community", "Mixed signals with one clear consensus"

      BODY rules:
      - Write 4 to 6 sentences in #{target_language}
      - Open with a bold overall characterization of the vote using <strong> tags
      - Identify 2-3 specific questions with notable results, quoting the winning answer with its percentage in <strong> tags — e.g. <strong>"Should cycling routes be expanded?" → Yes (80%)</strong>
      - Note at least one contested or polarizing question
      - If any rating-scale questions lean strongly positive or negative, mention them
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
