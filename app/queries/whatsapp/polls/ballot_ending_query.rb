class Whatsapp::Polls::BallotEndingQuery < ApplicationQuery
  # How a ballot asked in a chat came to its end, read once there is nothing left to
  # ask in it. Reaching the end is not answering everything: a skipped question is
  # passed over and holds no answer, so a ballot whose every question was skipped
  # ended exactly like one answered in full — and was confirmed as one, "every
  # answer recorded" over a ballot with nothing in it.
  #
  # Read from the recorded answers alone, the way Whatsapp::BallotParticipation
  # reads them for the counts and the marks, so the line closing a ballot and the
  # list of votes afterwards cannot tell the citizen two different things.
  #
  # `unanswered_questions` are the owed questions without any answer of theirs. A
  # map question given fewer points than it asks for is owed but not among them:
  # its points are in `answers`, and it is not a question they gave nothing to.
  Ending = Struct.new(:poll, :outcome, :answers, :unanswered_questions, keyword_init: true)

  def initialize(poll:, user:)
    @poll = poll
    @user = user
  end

  def call
    traversal = ::Polls::BallotTraversalQuery.for(poll: @poll, user: @user)
    answers = ::Whatsapp::Polls::BallotSummaryQuery.call(
      poll: @poll, user: @user, traversal: traversal
    )
    owed_questions = traversal.owed_questions
    answered_ids = answers.map { |entry| entry.question.id }

    Ending.new(
      poll: @poll,
      outcome: outcome_for(answers, owed_questions),
      answers: answers,
      unanswered_questions: owed_questions.reject { |question| answered_ids.include?(question.id) }
    )
  end

  private

    def outcome_for(answers, owed_questions)
      return ::Whatsapp::Polls::AdvanceBallotService::COMPLETED if owed_questions.empty?
      return ::Whatsapp::Polls::AdvanceBallotService::SKIPPED if answers.empty?

      ::Whatsapp::Polls::AdvanceBallotService::PARTLY_ANSWERED
    end
end
