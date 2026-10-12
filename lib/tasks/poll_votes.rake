namespace :poll_votes do
  desc "Report votes whose stored answer text matches no answer of their question"
  task answer_id_check: :environment do
    [::Poll::Answer, ::Poll::PartialResult].each do |model|
      table = model.table_name

      unmatched = model.where.not(answer: nil).where(
        "NOT EXISTS (
           SELECT 1
           FROM poll_question_answers qa
           JOIN poll_question_answer_translations t
             ON t.poll_question_answer_id = qa.id
           WHERE qa.question_id = #{table}.question_id
             AND t.title = #{table}.answer
         )"
      )

      count = unmatched.count
      puts format("  %-24s %6d of %d rows match no answer", table, count, model.count)

      next if count.zero?

      unmatched.limit(10).pluck(:question_id, :answer).each do |question_id, answer|
        puts format("    question %-8d %s", question_id, answer.inspect)
      end
    end

    ambiguous = ::Poll::Question::Answer
      .unscoped
      .joins(:translations)
      .group("poll_question_answers.question_id", "poll_question_answer_translations.title")
      .having("count(distinct poll_question_answers.id) > 1")
      .count("distinct poll_question_answers.id")

    puts format("  %-24s %6d titles shared by several answers of one question", "ambiguous", ambiguous.size)

    ambiguous.first(10).each do |(question_id, title), _count|
      puts format("    question %-8d %s", question_id, title.inspect)
    end
  end
end
