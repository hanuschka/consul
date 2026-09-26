class Whatsapp::Polls::RecordOpenAnswerService < ApplicationService
  # The citizen's own words, taken as the answer to the free-text question the bot
  # last asked. It is the one place a plain message means something other than a
  # question for the assistant, which is why the question has to have been written
  # down before the words could arrive — Whatsapp::Conversation#pending_open_question_id
  # is what says they were asked for.
  #
  # The write is the portal's own two steps, in the portal's own order: the answer
  # row is created under the open option's *title*, the way any other answer is,
  # and the words go into open_answer_text beside it. Poll::Answer records an answer
  # as the option it belongs to; free text is an option with a body attached, not a
  # body instead of an option. Skipping destroys the row rather than leaving it
  # empty, which is what PollsController#confirm_participation reaps on the page.
  def self.skip(conversation:)
    new(conversation: conversation, text: nil).skip!
  end

  def initialize(conversation:, text:)
    @conversation = conversation
    @text = text.to_s.strip
  end

  def call
    return false if !asked?
    return abandon if !still_votable?
    return false if @text.blank?

    record!
    @conversation.clear_pending_open_question!

    advance
  end

  # The question left unanswered on purpose. Nothing is written, anything written
  # before is removed, and the ballot carries on — an answer the citizen declined to
  # give is not a reason to end it.
  def skip!
    return false if !asked?
    return abandon if !still_votable?

    remove_previous_answer!
    @conversation.decline_poll_question!(question.id)
    @conversation.clear_pending_open_question!

    advance
  end

  private

    # That a free-text question was actually put to this citizen. Without it any
    # message would be a candidate answer to whatever question a marker happened to
    # name.
    def asked?
      question.present? && user.present? && open_option.present?
    end

    # The marker alone is not enough: it survives in the conversation while the poll
    # behind it can close, so the whole gate is asked again before the words are
    # taken as a vote.
    def still_votable?
      poll.present? && projekt_phase.permission_problem(user).blank?
    end

    # The markers go and the message goes to the assistant, which is where an
    # unrelated sentence belonged anyway.
    def abandon
      @conversation.clear_ballot!

      false
    end

    def record!
      answer = question.find_or_initialize_user_answer(user, open_option)

      answer.save_and_record_voter_participation if answer.new_record?
      answer.update!(open_answer_text: @text)
    end

    def remove_previous_answer!
      answer = question.answers.find_by(author: user, answer: open_option.title)

      return if answer.blank?

      answer.destroy_and_remove_voter_participation
    end

    def advance
      @conversation.store_active_poll!(poll.id)

      ::Whatsapp::Polls::AdvanceBallotService.call(conversation: @conversation, poll: poll)
    end

    def question
      return @question if defined?(@question)

      question_id = @conversation.pending_open_question_id

      @question = question_id.blank? ? nil : ::Poll::Question.find_by(id: question_id)
    end

    def open_option
      @open_option ||= question.open_question_answer
    end

    def poll
      return @poll if defined?(@poll)

      @poll = ::Whatsapp::VotableBallotQuery.for(projekt_phase)
    end

    def projekt_phase
      @projekt_phase ||= question&.poll&.projekt_phase
    end

    def user
      @conversation.user
    end
end
