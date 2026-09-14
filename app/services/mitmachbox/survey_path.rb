class Mitmachbox::SurveyPath
  def initialize(questions)
    @questions = (questions || []).each_with_index
                                  .sort_by { |question, index| [question["position"].to_i, index] }
                                  .map(&:first)
    @index_by_id = @questions.each_with_index.to_h { |question, index| [question["id"], index] }
  end

  def reached_question_ids(chosen_option_ids_by_question)
    reached = []
    index = 0

    while index < @questions.size
      question = @questions[index]
      reached << question["id"]
      option = branching_option(question, chosen_option_ids_by_question[question["id"]])

      if option.nil?
        index += 1
      elsif option["ends_survey"]
        break
      else
        target = @index_by_id[option["next_question_id"]]
        break if target.nil? || target <= index

        index = target
      end
    end

    reached
  end

  def on_path(answers)
    chosen = answers.group_by { |answer| answer[:question_id] }
                    .transform_values { |group| group.map { |answer| answer[:option_id] } }
    reached = reached_question_ids(chosen)

    answers.select { |answer| reached.include?(answer[:question_id]) }
  end

  private

    def branching_option(question, chosen_option_ids)
      return unless question["question_type"] == "single_choice"

      ids = Array(chosen_option_ids)
      return unless ids.size == 1

      option = (question["options"] || []).find { |candidate| candidate["id"] == ids.first }
      option if option && (option["ends_survey"] || option["next_question_id"].present?)
    end
end
