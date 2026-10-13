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
  # tool reporting into a turn. A ballot that ends without a question going out is not a
  # ballot that was started, and a tool that reports it as one has told the model the
  # citizen is looking at a question that was never sent.
  #
  # COMPLETED is a ballot answered to its end here and now, and only that. A vote the
  # citizen took part in some time before never reaches this at all — OfferBallotService
  # answers it before beginning anything, because the two need different words and
  # arriving here they had the same ones.
  #
  # Reaching the end is not the same as answering everything, because a skipped
  # question is passed over and holds no answer. PARTLY_ANSWERED is a ballot ended
  # with some questions still unanswered, SKIPPED one ended with no answer at all —
  # which is no vote, and was confirmed as a completed one. All three are endings
  # (ENDINGS); which one it was is Whatsapp::Polls::BallotEndingQuery's to read.
  ASKED = :asked
  COMPLETED = :completed
  PARTLY_ANSWERED = :partly_answered
  SKIPPED = :skipped

  ENDINGS = [COMPLETED, PARTLY_ANSWERED, SKIPPED].freeze

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
    #
    # What is confirmed is how the ballot ended (#ending), never "completed" by
    # default: a ballot skipped to its end has recorded nothing, and saying otherwise
    # had the bot report a vote nobody cast.
    def complete
      @conversation.clear_ballot!

      confirm_completion

      ending.outcome
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
        note: ::Whatsapp::CompletionNotes.ballot_ended(ending)
      )
    end

    # The fixed line carries the summary the assistant would have written, below it
    # and out of the translation, which rewords only the bot's own line: the
    # questions and answers are the poll's wording.
    def send_completed_line
      account = @conversation.whatsapp_account
      closing = ::Whatsapp::AiAssistant::BotCopyService.line(account: account, body: closing_copy)
      body = [
        closing,
        *ending.answers.map { |entry| summary_block(entry) },
        *skipped_blocks
      ].join("\n\n")

      ::Whatsapp::Send.text(
        account: account, body: body.truncate(::Whatsapp::MAX_TEXT_BODY_LENGTH)
      )
    end

    # Thanked for votes only where every question has an answer. Otherwise the line
    # says what was kept — the answers given, or nothing — and until when the rest
    # can still be answered: the phase's end, the date its permission check closes
    # the ballot on.
    def closing_copy
      closes_on = ::Whatsapp::DatePhrase.absolute(@poll.projekt_phase&.end_date)

      case ending.outcome
      when SKIPPED
        skipped_copy(closes_on)
      when PARTLY_ANSWERED
        partly_answered_copy(closes_on)
      else
        ::Whatsapp.copy("whatsapp.bot.poll.completed", poll: @poll.name)
      end
    end

    def skipped_copy(closes_on)
      if closes_on.blank?
        return ::Whatsapp.copy("whatsapp.bot.poll.skipped.open_ended", poll: @poll.name)
      end

      ::Whatsapp.copy("whatsapp.bot.poll.skipped.until_date", poll: @poll.name, date: closes_on)
    end

    def partly_answered_copy(closes_on)
      if closes_on.blank?
        return ::Whatsapp.copy("whatsapp.bot.poll.partly_answered.open_ended", poll: @poll.name)
      end

      ::Whatsapp.copy(
        "whatsapp.bot.poll.partly_answered.until_date", poll: @poll.name, date: closes_on
      )
    end

    def summary_block(entry)
      answered =
        if entry.map_points.positive?
          ::Whatsapp.copy(
            "whatsapp.bot.poll.summary_map_points",
            count: entry.map_points,
            locale: ::Whatsapp.locale_for(@conversation.whatsapp_account)
          )
        else
          entry.answers.join(", ")
        end

      "*#{entry.question.title}*\n#{answered}"
    end

    # A question left without an answer, listed under the answered ones so a summary
    # of half a ballot does not read as the whole of it. Not beside no answers at
    # all: a ballot skipped whole says so in its line, and every title under it
    # marked skipped would only repeat that.
    def skipped_blocks
      return [] if ending.answers.empty?

      skipped = ::Whatsapp.copy(
        "whatsapp.bot.poll.summary_skipped",
        locale: ::Whatsapp.locale_for(@conversation.whatsapp_account)
      )

      ending.unanswered_questions.map { |question| "*#{question.title}*\n#{skipped}" }
    end

    # Read after the markers are cleared, which it does not depend on: how a ballot
    # ended is a fact about the recorded answers.
    def ending
      @ending ||= ::Whatsapp::Polls::BallotEndingQuery.call(
        poll: @poll, user: @conversation.user
      )
    end
end
