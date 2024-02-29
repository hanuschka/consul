module CsvServices
  class PollAnswersVotesExporter < ApplicationService
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

          csv << []

          root_question.nested_questions.map do |nested_question|
            csv << question_headers(nested_question)

            nested_question.question_answers.each do |question_answer|
              csv << row(question_answer)
            end

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
  end
end
