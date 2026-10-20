class Whatsapp::Polls::OwedQuestionQuery < ApplicationQuery
  # The ballot question in front of the citizen right now, as the position the
  # ballot is at, or nothing outside a ballot.
  #
  # Walked from the recorded answers the way every other step of the ballot is —
  # never the last question this conversation happened to write down, which a
  # branch or an answer given on the page since would have moved past. A free-text
  # question armed for the citizen's words is the one marker read as it stands:
  # tapping a question's open option arms it while the walk still names that
  # question, and the marker is what says the words were asked for.
  def self.for(conversation:)
    new(conversation: conversation).call
  end

  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    return if poll.blank?
    return if @conversation.user.blank?
    return pending_open_position if @conversation.pending_open_question_id.present?

    ::Polls::BallotTraversalQuery
      .for(poll: poll, user: @conversation.user)
      .first_owed(
        still_choosing_question_id: @conversation.open_multiple_question_id,
        declined_question_ids: @conversation.declined_poll_question_ids
      )
  end

  private

    def pending_open_position
      question = poll.questions.find_by(id: @conversation.pending_open_question_id)

      return if question.blank?

      ::Polls::BallotTraversalQuery::Position.new(question: question)
    end

    def poll
      return @poll if defined?(@poll)

      @poll = ::Poll.find_by(id: @conversation.active_poll_id)
    end
end
