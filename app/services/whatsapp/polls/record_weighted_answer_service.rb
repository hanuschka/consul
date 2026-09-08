class Whatsapp::Polls::RecordWeightedAnswerService < ApplicationService
  # A tap on one of the numbers offered beside one choice of a weighted question,
  # recorded as that much of the question's budget on that choice. The write is the
  # portal's own — Questionable#find_or_initialize_user_answer, which for a weighted
  # question finds the row belonging to this option, and then
  # Poll::Answer#save_and_record_voter_participation — so a weight given here is the
  # same row, with the same voter participation beside it, as one given on the page.
  #
  # Zero is a weight like any other and is written like one. It is what a citizen
  # says when a choice is to carry nothing, and the row is what lets the walk move
  # past a choice that has been answered: without it, "no weight" and "not asked
  # yet" are the same absence.
  #
  # The question stays open across the whole walk of its choices. What holds it open
  # is the marker a multiple-choice question uses (Whatsapp::Conversation
  # #open_multiple_question_id), because the two have the same problem — their first
  # recorded answer is not the end of them — and it is dropped here as soon as there
  # is nothing left to ask.
  #
  # Everything is re-resolved and re-checked on arrival. A pill sits in a chat for as
  # long as the chat does: the poll may have closed, the phase may have been taken
  # down, and the budget may since have been spent elsewhere — on the page, or on a
  # pill further up. The maximum is the portal's own reading of it
  # (Polls::AnswerAllowanceQuery), which is what the page refuses a write against.
  def initialize(conversation:, question_answer:, weight:)
    @conversation = conversation
    @question_answer = question_answer
    @weight = weight.to_i
  end

  def call
    return false if user.blank?
    return false if !weighted?
    return false if !votable?
    return refuse_over_maximum if !room_for_this_weight?

    record!
    settle_question!

    advance
  end

  private

    # The tap is honoured for any weighted question of a ballot the chat can still
    # carry, not only the one last asked: a citizen scrolling back to change a weight
    # they already gave is doing what the page lets them do, and what is free for
    # that choice counts their own weight back in.
    def votable?
      poll.present? &&
        question.poll_id == poll.id &&
        projekt_phase.permission_problem(user).blank?
    end

    def weighted?
      ::Whatsapp::VotableBallotQuery.weighted?(question)
    end

    def poll
      return @poll if defined?(@poll)

      @poll = ::Whatsapp::VotableBallotQuery.for(projekt_phase)
    end

    def room_for_this_weight?
      ::Polls::AnswerAllowanceQuery.call(
        question: question, user: user, title: @question_answer.title, weight: @weight
      )
    end

    # Reached from a pill further up the chat, or from a budget spent on the page
    # since this one was sent. Said rather than silently ignored — a tap that
    # produces nothing reads as a bot that has died — and then the question is put
    # again, with the numbers that are actually free now.
    def refuse_over_maximum
      ::Whatsapp::Send.locale_text(
        account: @conversation.whatsapp_account,
        body: I18n.t(
          "whatsapp.bot.poll.weight_maximum_reached", remaining: remaining_weight
        )
      )

      advance
    end

    def remaining_weight
      ::Polls::AnswerAllowanceQuery.remaining_weight(
        question: question, user: user, title: @question_answer.title
      )
    end

    # The title read off the record rather than off the button the citizen tapped:
    # the pill carries an option id and a number, and Poll::Answer records the answer
    # as text.
    def record!
      answer = question.find_or_initialize_user_answer(user, @question_answer.title)
      answer.answer_weight = @weight

      answer.save_and_record_voter_participation
    end

    # The question stops being the one the citizen is working through when every
    # choice has a weight, or when the budget is spent — either way there is nothing
    # left to offer, and the marker held the question open past that.
    def settle_question!
      return if more_to_weight?

      @conversation.clear_open_multiple_question!
    end

    def more_to_weight?
      next_choice = question.question_answers.reject do |option|
        weighted_titles.include?(option.title)
      end.first

      return false if next_choice.blank?

      ::Polls::AnswerAllowanceQuery.remaining_weight(
        question: question, user: user, title: next_choice.title
      ).to_i.positive?
    end

    def weighted_titles
      ::Poll::Answer.where(question_id: question.id, author: user).pluck(:answer)
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
