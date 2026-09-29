class Whatsapp::Polls::RecordAnswerService < ApplicationService
  # A tap on one of the answer pills, recorded as the vote it is. The write is the
  # portal's own — Questionable#find_or_initialize_user_answer followed by
  # Poll::Answer#save_and_record_voter_participation — so a vote cast here is the
  # same row, with the same voter participation beside it, as a vote cast on the
  # page. The bot owning a second way to write one is how the two come to disagree.
  #
  # Everything is re-resolved and re-checked on arrival. A pill sits in a chat
  # history for as long as the chat does: the poll it belongs to may have closed,
  # the phase may have been taken down, the citizen may have unlinked since. False
  # is the caller's signal that the tap could not be honoured, and the assistant is
  # what says why — it says it better than a fixed line.
  #
  # A vote already cast is replaced rather than refused, which is what a `unique`
  # question does on the portal too: one answer per citizen, and the last one given
  # is it. A `multiple` question accumulates instead, one row per chosen option, and
  # tapping the same option twice finds the row it already wrote — the pill for a
  # choice already made is dropped from the next message, so a second tap on one can
  # only come from a message further up the chat.
  #
  # The maximum a `multiple` question allows is enforced here rather than delegated
  # with the write. On the page the cap lives in the view — the button for a choice
  # past it is rendered disabled — and Polls::QuestionsController#answer records
  # whatever it is handed, so there is nothing underneath to inherit it from.
  def initialize(conversation:, question_answer:)
    @conversation = conversation
    @question_answer = question_answer
  end

  def call
    return false if user.blank?
    return false if !votable?

    return ask_for_text if @question_answer.open_answer?
    return refuse_over_maximum if !room_for_this_choice?

    record!
    settle_question!

    advance
  end

  private

    # The tap is honoured for any question of a ballot the chat can still carry,
    # not only the one last asked: a citizen scrolling back to change an answer they
    # already gave is doing what the page lets them do, and the cursor moves on from
    # wherever the answers now stand.
    def votable?
      poll.present? &&
        question.poll_id == poll.id &&
        projekt_phase.permission_problem(user).blank?
    end

    def poll
      return @poll if defined?(@poll)

      @poll = ::Whatsapp::VotableBallotQuery.for(projekt_phase)
    end

    # An option flagged open_answer records nothing on its own — what it stands for
    # is the citizen's own words, and they have not been written yet. The tap arms
    # the question for the next message and asks for them.
    def ask_for_text
      ::Whatsapp::Polls::AskQuestionService.for_open_answer(
        conversation: @conversation, question: question
      )
    end

    # The portal's own reading of its own maximum, which Polls::AnswerAllowanceQuery
    # owns and Polls::QuestionsController#answer refuses a write against. It used to
    # be counted here as well, because the page enforced the cap only by disabling a
    # button and there was nothing underneath to inherit it from.
    def room_for_this_choice?
      ::Polls::AnswerAllowanceQuery.call(
        question: question, user: user, title: @question_answer.title
      )
    end

    # Reached only from a pill further up the chat: the current message drops every
    # option already chosen and stops offering any once the maximum is spent. Said
    # rather than silently ignored, because a tap that produces nothing reads as a
    # bot that has died.
    def refuse_over_maximum
      ::Whatsapp::Send.locale_text(
        account: @conversation.whatsapp_account,
        body: ::Whatsapp.copy("whatsapp.bot.poll.maximum_reached", maximum: question.max_votes)
      )

      true
    end

    # The option record rather than the button the citizen tapped: the button
    # carries at most twenty characters of the title, so identifying the answer by
    # what it said would file a vote under a cut phrase that matches no option the
    # poll has.
    def record!
      answer = question.find_or_initialize_user_answer(user, @question_answer)

      answer.save_and_record_voter_participation
    end

    # A `multiple` question stops being the one the citizen is choosing from when
    # their last allowed choice is spent, or when there is nothing left to choose.
    # Until then the marker holds it open, because the recorded answers alone would
    # have the cursor move past a question after its first choice.
    def settle_question!
      return if !question.multiple?

      chosen = ::Poll::Answer.where(question_id: question.id, author: user).count

      return if chosen < question.max_votes && chosen < question.question_answers.size

      @conversation.clear_open_multiple_question!
    end

    def advance
      @conversation.store_active_poll!(poll.id)

      ::Whatsapp::Polls::AdvanceBallotService.call(conversation: @conversation, poll: poll)
    end

    def question
      @question ||= @question_answer.question
    end

    def projekt_phase
      @projekt_phase ||= question&.poll&.projekt_phase
    end

    def user
      @conversation.user
    end
end
