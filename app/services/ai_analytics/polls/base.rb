class AiAnalytics::Polls::Base < ApplicationService
  def initialize(poll, prompt:, stat_key:, output_schema:)
    @poll = poll
    @prompt = prompt
    @stat_key = stat_key
    @output_schema = output_schema
  end

  def call
    return {} if detailed_questions_data.empty?

    Rails.logger.info("[AI Analytics] Polls::Base: Starting #{@stat_key} for poll ##{@poll.id}")

    result = generate_analysis
    store_result(result)

    Rails.logger.info("[AI Analytics] Polls::Base: Completed #{@stat_key} for poll ##{@poll.id}")
    result
  end

  private

  def generate_analysis
    chat = Ai::RubyLlmFactory.chat(feature: "ai_analytics.poll_#{@stat_key}")
      .with_schema(@output_schema)
      .with_instructions(Ai::EvaluationContext.prepend_to(system_instructions, @poll))

    response = chat.ask(user_prompt)
    response.content
  end

  def system_instructions
    <<~TEXT
      #{@prompt}

      Formating guideline:
      - Use semantic HTML structure (e.g. <h4>, <p>, <ul>, <li>) where helpful.
      - Dont add spaces before <li> items.
      - Structure your answer clearly with paragraphs
      - Dont use br html tags

      Output response in #{target_language} language.
    TEXT
  end

  def user_prompt
    <<~TEXT
      Poll: #{@poll.name}
      Summary: #{@poll.summary}
      Total Voters: #{@poll.voters.count}
      Total Responses: #{Poll::Answer.where(question: @poll.questions).count}

      Questions and Results (JSON):
      #{detailed_questions_json}

      Citizen Comments:
      #{formatted_comments}
    TEXT
  end

  def store_result(result)
    current_stats = @poll.ai_stats || {}
    current_stats[@stat_key] = result[@stat_key]
    @poll.update_column(:ai_stats, current_stats)
  end

  def target_language
    Rails.env.development? ? "English" : "German"
  end

  def detailed_questions_data
    @detailed_questions_data ||= @poll.questions
      .root_questions
      .where(contextualize_by_poll_question_id: nil)
      .order(given_order: :asc, id: :asc)
      .includes(:context, :question_answers, nested_questions: [:context, :question_answers])
      .map { |q| build_question_data(q) }
  end

  def build_question_data(question)
    answers = question.question_answers.to_a
    vote_totals = answers.map(&:total_votes)
    answers_total_votes = vote_totals.sum

    data = {
      title: question_title(question),
      answers: answers.each_with_index.map do |answer, index|
        votes = vote_totals[index]
        {
          title: answer.title,
          votes: votes,
          percentage: (answers_total_votes.zero? ? 0 : (votes * 100.0 / answers_total_votes)).round(2)
        }
      end
    }

    open_answer = question.open_question_answer
    if open_answer.present? && open_answer.all_open_answers.present?
      data[:open_answers] = open_answer.all_open_answers.map(&:open_answer_text).compact
    end

    if question.nested_questions.any?
      data[:nested_questions] = question.nested_questions.map { |nq| build_question_data(nq) }
    end

    data
  end

  def question_title(question)
    question.context.present? ? "#{question.title} (#{question.context.title})" : question.title
  end

  def detailed_questions_json
    JSON.pretty_generate(detailed_questions_data)
  end

  def comments_data
    @comments_data ||= @poll.comments
      .order(:created_at)
      .limit(20)
      .pluck(:body)
      .map { |body| body&.truncate(300) }
      .compact
  end

  def formatted_comments
    return "No comments" if comments_data.empty?
    comments_data.join("\n- ")
  end
end
