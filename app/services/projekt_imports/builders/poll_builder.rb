class ProjektImports::Builders::PollBuilder < ProjektImports::Builders::Base
  DEFAULT_VOTE_TYPE = "unique".freeze

  # The single definition of "a poll question this import can actually build".
  # The chat's question count and the empty-voting-phase warning both ask here,
  # so what the admin is told always matches what gets created.
  def self.importable_questions(payload)
    Array(payload).select { |question| question["title"].present? }
  end

  def call
    questions = self.class.importable_questions(payload)
    return [] if questions.empty?

    poll = phase.poll || phase.create_poll!(name: phase.name.presence || projekt.name)
    order_offset = poll.questions.maximum(:given_order).to_i

    questions.map.with_index(1) do |question, position|
      build_question(poll, question, order_offset + position)
    end
  end

  private

  def build_question(poll, payload_question, given_order)
    question = poll.questions.new(
      title: payload_question["title"],
      description: payload_question["description"],
      author: projekt.author,
      given_order: given_order
    )
    question.votation_type = build_votation_type(payload_question)
    question.save!

    build_answers(question, payload_question["answers"])

    question
  rescue ActiveRecord::RecordInvalid => e
    raise ProjektImports::Builders::BuilderError,
      "poll_question(#{payload_question['title']}): #{e.message}"
  end

  def build_votation_type(payload_question)
    VotationType.new(
      vote_type: vote_type_for(payload_question),
      min_rating_scale_label: payload_question["min_rating_scale_label"].presence,
      max_rating_scale_label: payload_question["max_rating_scale_label"].presence
    )
  end

  def vote_type_for(payload_question)
    requested = payload_question["vote_type"].to_s
    return requested if VotationType.vote_types.key?(requested)

    DEFAULT_VOTE_TYPE
  end

  def build_answers(question, payload_answers)
    answers = Array(payload_answers).select { |answer| answer["title"].present? }

    answers.each_with_index do |answer, index|
      question.question_answers.create!(
        title: answer["title"],
        description: answer["description"].to_s,
        given_order: index + 1
      )
    end
  end
end
