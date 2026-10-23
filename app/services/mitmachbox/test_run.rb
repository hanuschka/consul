class Mitmachbox::TestRun
  attr_reader :questions, :answers

  def initialize(questions, answers: {}, answered_question_id: nil)
    @questions = (questions || []).sort_by { |question| question["position"].to_i }
    @path = Mitmachbox::SurveyPath.new(@questions)
    @answers = answers
    @answered_question = find(answered_question_id.presence&.to_i)
  end

  def missing_required_answer?
    @answered_question.present? && @answered_question["required"] &&
      Array(answers[@answered_question["id"]]).empty?
  end

  def current_question
    return @current_question if defined?(@current_question)

    @current_question = missing_required_answer? ? @answered_question : find(next_question_id)
  end

  def finished?
    current_question.nil?
  end

  def step
    @step ||= @path.reached_question_ids(answers).index(current_question&.dig("id")).to_i + 1
  end

  def total
    return @total if defined?(@total)

    @total = (@path.progress_total(current_question["id"], step, drafted_answers) if current_question)
  end

  def previous_answers
    answers.except(current_question&.dig("id"))
  end

  private

    def drafted_answers
      previous_answers.flat_map do |question_id, option_ids|
        Array(option_ids).map { |option_id| [question_id, option_id] }
      end
    end

    def next_question_id
      reached = @path.reached_question_ids(answers)
      return reached.first if @answered_question.nil?

      index = reached.index(@answered_question["id"])
      reached[index + 1] if index
    end

    def find(question_id)
      questions.find { |question| question["id"] == question_id } if question_id
    end
end
