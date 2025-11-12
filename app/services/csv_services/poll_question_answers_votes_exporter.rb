module CsvServices
  class PollQuestionAnswersVotesExporter < CsvServices::BaseService
    require "csv"

    def initialize(question)
      @question = question
      @poll = question.poll
      @other_poll_questions = @poll.questions.root_questions.where.not(id: @question.id)
    end

    def call
      CSV.generate(headers: false, col_sep: ";", force_quotes: true, encoding: "UTF-8") do |csv|
        csv << headers(@question)

        @other_poll_questions.each do |question|
          if question.nested_questions.any?
            question.nested_questions.each do |nested_question|
              nested_question.question_answers.each do |question_answer|
                csv << row(nested_question, question_answer)
              end
            end
          else
            question.question_answers.each do |question_answer|
              csv << row(question, question_answer)
            end
          end
        end
      end
    end

    private

      def headers(question)
        headers = []
        headers.push(question_title(question))
        headers.push("Antworten")
        question.question_answers.each do |qa|
          headers.push("#{qa.title} (#{qa.total_votes})")
          headers.push("%")
        end
        headers
      end

      def row(question, question_answer)
        row = []
        row.push(question_title(question))
        row.push(question_answer.title)

        @question.question_answers.each do |base_question_answer|
          row.push question_answer.total_connected_votes_to(base_question_answer)
          row.push number_to_percentage(
                     question_answer.total_connected_votes_inner_share(base_question_answer),
                     precision: 2,
                     strip_insignificant_zeros: true,
                     separator: ",",
                     format: "%n%"
                   )
        end

        row
      end

      def question_title(question)
        if question.parent_question.present?
          "#{question.title} (#{question.parent_question.title})"
        else
          question.title
        end
      end
  end
end
