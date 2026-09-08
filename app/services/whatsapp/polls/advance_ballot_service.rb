class Whatsapp::Polls::AdvanceBallotService < ApplicationService
  # Where a ballot goes next, asked after every answer and again after a question
  # the citizen asked in the middle of one. The only place that decides between
  # another question and a closing line, so the two cannot disagree about when a
  # ballot is over.
  #
  # Everything is re-resolved on arrival. A ballot is asked over as many messages as
  # it has questions, and between any two of them the poll may have closed, the phase
  # may have been taken down, the citizen may have unlinked. None of that is an
  # error to report: the answers already given stand, the markers are dropped, and
  # what is said next belongs to the assistant, which says it better than a fixed
  # line.
  def initialize(conversation:, poll:)
    @conversation = conversation
    @poll = poll
  end

  def call
    return abandon if !still_votable?
    return abandon if @conversation.user.blank?

    position = ::Whatsapp::BallotCursorQuery.for(
      poll: @poll,
      user: @conversation.user,
      still_choosing_question_id: @conversation.open_multiple_question_id,
      declined_question_ids: @conversation.declined_poll_question_ids
    )

    return complete if position.blank?

    ::Whatsapp::Polls::AskQuestionService.call(
      conversation: @conversation, position: position
    ) || complete
  end

  private

    # The poll is checked through its own phase rather than by asking whether it is
    # published: what makes a poll answerable in a chat is the whole gate — the phase
    # running, the poll being the phase's own and published, and every question in it
    # being a shape a chat can ask.
    def still_votable?
      ::Whatsapp::VotableBallotQuery.for(@poll.projekt_phase) == @poll
    end

    # Silence and no markers. Reached where the ballot cannot be carried on, which
    # from the citizen's side is a message they did not ask for not arriving.
    def abandon
      @conversation.clear_ballot!

      false
    end

    # The last question is answered, so the ballot is closed off explicitly. A ballot
    # that simply stops sending questions is indistinguishable from a bot that has
    # died mid-vote, which is the reading this one line exists to prevent.
    def complete
      @conversation.clear_ballot!

      ::Whatsapp::Send.locale_text(
        account: @conversation.whatsapp_account,
        body: I18n.t("whatsapp.bot.poll.completed", poll: @poll.name)
      )

      true
    end
end
