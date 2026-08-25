module CsvServices
  class PollIndividualAnswersExporter < CsvServices::BaseService
    require "csv"

    def initialize(poll)
      @poll = poll
    end

    def call
      CSV.generate(headers: true, col_sep: ";", force_quotes: true, encoding: "UTF-8") do |csv|
        csv << headers

        answers.each do |answer|
          csv << row(answer)
        end
      end
    end

    private

      def headers
        [
          "Teilnehmer",
          "Frage",
          "Antwort",
          "Offene Antwort",
          "Gewicht",
          "Abgegeben am"
        ]
      end

      def row(answer)
        [
          respondent_token(answer.author_id),
          sanitize_for_csv(strip_tags(question_title(answer.question))),
          sanitize_for_csv(strip_tags(answer_text(answer))),
          sanitize_for_csv(strip_tags(answer.open_answer_text)),
          answer.answer_weight,
          answer.created_at&.strftime("%d.%m.%Y %H:%M")
        ]
      end

      def answer_text(answer)
        return answer.answer unless answer.map_points?

        I18n.t("custom.polls.questions.map_points.csv_pin_count", count: answer.map_points.size)
      end

      def answers
        @answers ||= Poll::Answer
          .where(question_id: @poll.question_ids)
          .includes(:map_points, question: [:context, :votation_type])
          .order(:author_id, :question_id, :id)
      end

      # Maps each author to a stable, sequential pseudonym (R001, R002, ...) so
      # answers from the same person stay linkable without exposing any personal
      # data. Ordered by author_id, so the mapping is deterministic for a given
      # set of respondents.
      def respondent_token(author_id)
        tokens[author_id]
      end

      def tokens
        @tokens ||= begin
          author_ids = answers.map(&:author_id).uniq
          width = [author_ids.size.to_s.length, 3].max

          author_ids.each_with_index.each_with_object({}) do |(author_id, index), map|
            map[author_id] = "R#{(index + 1).to_s.rjust(width, "0")}"
          end
        end
      end

      def question_title(question)
        question.context.present? ? "#{question.title} (#{question.context.title})" : question.title
      end
  end
end
