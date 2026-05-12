class Evaluations::GroupPollQuestions < ApplicationService
  MIN_QUESTIONS_FOR_GROUPING = 3

  def initialize(questions)
    @questions = questions || []
  end

  def call
    return [] if @questions.size < MIN_QUESTIONS_FOR_GROUPING

    prompt = build_user_prompt
    response_text = get_ai_response(prompt)
    groups = parse_response(response_text)

    validate_and_fix_coverage(groups)
  rescue StandardError => e
    Rails.logger.error("[Evaluation] GroupPollQuestions failed: #{e.message}")
    []
  end

  private

  def target_language
    Rails.env.development? ? "English" : "German"
  end

  def build_user_prompt
    questions_text = @questions.map { |q| serialize_question(q) }.join("\n\n")

    <<~TEXT
      Questions:
      #{questions_text}
    TEXT
  end

  def serialize_question(question)
    answers = (question[:answers] || [])
      .map { |a| "    - #{a[:title]}" }
      .first(6)
      .join("\n")

    <<~Q
      - ID #{question[:id]}: "#{question[:title]}"
        Vote type: #{question[:vote_type]}
        Sample answers:
      #{answers}
    Q
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
      You are organizing poll questions for a civic engagement dashboard.

      Task: group the questions below by SEMANTIC THEME — what topic they ask about — not by question format.

      Return ONLY valid JSON in this shape:
      {
        "groups": [
          {"label": "Thematic name", "question_ids": [1, 2, 3]},
          {"label": "Another theme", "question_ids": [4, 5]}
        ]
      }

      RULES:
      - Each question ID must appear in EXACTLY ONE group — no duplicates, no omissions
      - Group questions that share a topic (e.g., all demographics together, all traffic-perception together, all yes/no measures together)
      - Labels: 1 to 3 words in #{target_language}, title case
      - Typical labels: "Teilnehmerprofil", "Wahrnehmung Durchgangsverkehr", "Bewertung Einbahnstraßen", "Begleitmaßnahmen", "Participants Profile", "Traffic Perception", "Accompanying Measures", "Safety Priorities"
      - Create 2 to 6 groups total
      - Do NOT create a group with fewer than 2 questions unless unavoidable (merge small themes into a larger group)
      - Preserve the original ID numbers exactly as given

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
    groups = data["groups"]

    return [] if groups.nil? || !groups.is_a?(Array)

    groups.map do |g|
      {
        label: g["label"].to_s.strip,
        question_ids: Array(g["question_ids"]).map(&:to_i)
      }
    end
  rescue JSON::ParserError => e
    Rails.logger.error("[Evaluation] Failed to parse grouping response: #{e.message}")
    []
  end

  def validate_and_fix_coverage(groups)
    return [] if groups.empty?

    all_question_ids = @questions.map { |q| q[:id].to_i }
    grouped_ids = groups.flat_map { |g| g[:question_ids] }.uniq
    missing_ids = all_question_ids - grouped_ids
    extra_ids = grouped_ids - all_question_ids

    groups.each do |group|
      group[:question_ids] = group[:question_ids] - extra_ids
    end

    if missing_ids.any?
      fallback_label = I18n.t("adm.projekts.projekts.evaluation.other_questions_group", default: "Other")
      existing = groups.find { |g| g[:label].downcase == fallback_label.downcase }

      if existing
        existing[:question_ids] = (existing[:question_ids] + missing_ids).uniq
      else
        groups << { label: fallback_label, question_ids: missing_ids }
      end
    end

    groups.reject { |g| g[:question_ids].empty? }
  end
end
