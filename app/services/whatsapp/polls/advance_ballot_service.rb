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
  #
  # ── What it answers, and why abandoning is the false one ────────────────────
  # ASKED and COMPLETED are both "the citizen has been sent something", which is what
  # every gate that calls this needs to know — so they are truthy and abandoning is
  # plain false, exactly as this read before the two were told apart. A gate reading a
  # false falls through to the assistant, which is the whole of what abandoning means.
  #
  # The two are told apart for the one caller that has to say something about the
  # ballot afterwards: Whatsapp::Polls::OfferBallotService, whose own caller may be a
  # tool reporting into a turn. A ballot with nothing left to ask is not a ballot that
  # was started, and a tool that reports it as one has told the model the citizen is
  # looking at a question that was never sent.
  ASKED = :asked
  COMPLETED = :completed

  def initialize(conversation:, poll:)
    @conversation = conversation
    @poll = poll
  end

  def call
    return abandon if !still_votable?
    return abandon if @conversation.user.blank?

    position = ::Polls::BallotTraversalQuery
      .for(poll: @poll, user: @conversation.user)
      .first_owed(
        still_choosing_question_id: @conversation.open_multiple_question_id,
        declined_question_ids: @conversation.declined_poll_question_ids
      )

    return complete if position.blank?

    return ASKED if ::Whatsapp::Polls::AskQuestionService.call(
      conversation: @conversation, position: position
    )

    complete
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
    # died mid-vote, which is the reading this exists to prevent.
    #
    # Handed to the assistant rather than said in one fixed line, because closing the
    # ballot off and closing the conversation are two different things and the line did
    # both: it confirmed the vote with nothing under it to tap, which reads as the bot
    # being finished with the citizen. What the assistant says instead is the
    # confirmation and whatever plausibly follows it in this projekt.
    #
    # The fixed line stays as the answer for a model that cannot be reached: the
    # confirmation is the half of this that must arrive whatever else fails. It is held
    # back for a turn already in flight, which is the one case where something else is
    # about to say this — the tool that got here reports the completion as its result,
    # and a fixed line beside that reply would confirm the vote twice.
    def complete
      @conversation.clear_ballot!

      confirm_completion

      COMPLETED
    end

    # The citizen is confirmed by whichever route can reach them: the assistant carrying
    # the conversation on, the turn this was reached from reporting the completion as
    # its own result, or — where neither can — the fixed line.
    def confirm_completion
      return if carry_on != ::Whatsapp::AiAssistant::ContinueConversationService::UNAVAILABLE

      send_completed_line
    end

    def carry_on
      ::Whatsapp::AiAssistant::ContinueConversationService.call(
        conversation: @conversation,
        note: ::Whatsapp::CompletionNotes.ballot_finished(poll: @poll)
      )
    end

    def send_completed_line
      ::Whatsapp::Send.locale_text(
        account: @conversation.whatsapp_account,
        body: ::Whatsapp.copy("whatsapp.bot.poll.completed", poll: @poll.name)
      )
    end
end
