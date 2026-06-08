class ProjektImports::Builders::PollBuilder < ProjektImports::Builders::Base
  def call
    questions = Array(payload)
    return [] if questions.empty?

    poll = phase.poll || phase.create_poll!(name: phase.name.presence || projekt.name)

    questions.filter_map do |q|
      next nil if q["title"].blank?

      build_question(poll, q)
    end
  end

  private

  def build_question(poll, q)
    question = poll.questions.create!(
      title: q["title"],
      description: q["description"]
    )

    Array(q["answers"]).each do |a|
      next if a["title"].blank?

      question.question_answers.create!(
        title: a["title"],
        description: a["description"]
      )
    end

    question
  rescue ActiveRecord::RecordInvalid => e
    raise ProjektImports::Builders::BuilderError, "poll_question(#{q['title']}): #{e.message}"
  end
end
