class Whatsapp::Polls::FinishMultipleQuestionService < ApplicationService
  # "I have picked everything I want" on a multiple-choice question, whether the
  # done pill was tapped or the citizen wrote it. It settles the question rather
  # than answering it — whatever was chosen is already recorded, each choice as it
  # was made — so all it does is let the ballot move on.
  #
  # The question it settles is the one the conversation holds open, never one the
  # caller names: both callers check that the citizen meant that one, and the marker
  # is what the walk reads to keep the question in front of them.
  #
  # Nothing chosen yet is the one thing it cannot settle. The walk reads the
  # recorded answers, and a question with none is still owed, so moving on would put
  # the same question again with nothing said about why. NOTHING_CHOSEN leaves the
  # question open and says so, for the caller to explain in its own way: the tap
  # with a fixed line, the assistant in its reply.
  NOTHING_CHOSEN = :nothing_chosen

  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    return false if @conversation.user.blank?
    return NOTHING_CHOSEN if nothing_chosen?

    @conversation.clear_open_multiple_question!

    advance
  end

  private

    def nothing_chosen?
      ::Poll::Answer
        .where(question_id: @conversation.open_multiple_question_id, author: @conversation.user)
        .none?
    end

    def advance
      poll = ::Poll.find_by(id: @conversation.active_poll_id)

      return false if poll.blank?

      ::Whatsapp::Polls::AdvanceBallotService.call(conversation: @conversation, poll: poll)
    end
end
