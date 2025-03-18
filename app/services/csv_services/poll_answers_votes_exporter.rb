module CsvServices
  class PollAnswersVotesExporter < CsvServices::BaseService
    require "csv"

    def initialize(poll)
      @poll = poll
    end

    def call
      CSV.generate(headers: false, col_sep: ";") do |csv|
        @poll.questions.root_questions.each do |root_question|
          csv << question_headers(root_question)

          root_question.question_answers.each do |question_answer|
            csv << row(question_answer)
          end

          process_open_answers(root_question, csv)

          csv << []

          root_question.nested_questions.map do |nested_question|
            csv << question_headers(nested_question)

            nested_question.question_answers.each do |question_answer|
              csv << row(question_answer)
            end

            process_open_answers(nested_question, csv)

            csv << []
          end
        end
      end
    end

    private

      def question_headers(question)
        headers = []
        headers.push(question.title)

        if question.question_answers.any?
          headers.push("Stimmenanzahl")
          headers.push("%")
        end

        headers
      end

      def row(question_answer)
        row = []
        row.push question_answer.title
        row.push question_answer.total_votes
        row.push question_answer.total_votes_percentage.round(2)
        row
      end

      def process_open_answers(question, csv)
        open_answer = question.open_question_answer
        return if open_answer.blank? || open_answer.all_open_answers.blank?

        open_answer.all_open_answers.each do |user_open_answer|
          csv << [sanitize_for_csv(user_open_answer.open_answer_text), "offene Antwort"]
        end
      end
  end
end
