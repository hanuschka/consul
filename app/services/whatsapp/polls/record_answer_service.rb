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
  # tapping an option already chosen takes it back (#withdraw) — the marked pill is
  # the page's ticked checkbox, and a second click on that unticks it.
  #
  # The maximum a `multiple` question allows is enforced here rather than delegated
  # with the write. On the page the cap lives in the view — the button for a choice
  # past it is rendered disabled — and Polls::QuestionsController#answer records
  # whatever it is handed, so there is nothing underneath to inherit it from.
  #
  # The options come as a list because a typed answer can name several options of a
  # multiple question at once, and a tap is a list of one. They are recorded together
  # or not at all: a message read as two choices of which only the first fits under
  # the maximum is not a message choosing the first.
  def initialize(conversation:, question_answers:)
    @conversation = conversation
    @question_answers = question_answers
  end

  def call
    return false if @question_answers.empty?
    return false if user.blank?
    return false if !votable?

    if @question_answers.any?(&:open_answer?)
      return ask_for_text
    end

    return withdraw if withdrawal?
    return refuse_over_maximum if !room?

    record!

    advance
  end

  # Whether this takes a choice back rather than making one: a single option of a
  # multiple question, already among the citizen's choices. Public for the typed
  # answer, which says what it read before anything is recorded and has to say
  # the right one of the two.
  def withdrawal?
    @question_answers.one? &&
      user.present? &&
      question.multiple? &&
      withdrawn_answer.present?
  end

  # The portal's own reading of its own maximum, which Polls::AnswerAllowanceQuery
  # owns and Polls::QuestionsController#answer refuses a write against. It used to
  # be counted here as well, because the page enforced the cap only by disabling a
  # button and there was nothing underneath to inherit it from.
  #
  # Asked per option and, for a multiple question, once more for the set: each
  # option passing against the rows as they stand says nothing about all of them
  # together, and the portal never records two at once to have a reading of that.
  # Public for the typed answer, which has the citizen asked back rather than
  # refused with the fixed line.
  def room?
    return false if @question_answers.empty?

    each_allowed = @question_answers.all? do |option|
      ::Polls::AnswerAllowanceQuery.call(
        question: question, user: user, title: option.title, recorded_answers: recorded_answers
      )
    end

    each_allowed && set_fits?
  end

  private

    # The tap is honoured for any question of a ballot the chat can still carry,
    # not only the one last asked: a citizen scrolling back to change an answer they
    # already gave is doing what the page lets them do, and the cursor moves on from
    # wherever the answers now stand.
    def votable?
      poll.present? &&
        question.poll_id == poll.id &&
        @question_answers.all? { |option| option.question_id == question.id } &&
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

    # A question that takes one answer is answered by one option, whatever else the
    # message seemed to name: recording two would have the second replace the first.
    def set_fits?
      if question.multiple?
        within_maximum?
      else
        @question_answers.one?
      end
    end

    def within_maximum?
      chosen_titles = recorded_answers.map(&:answer) | @question_answers.map(&:title)

      chosen_titles.size <= question.max_votes
    end

    def recorded_answers
      @recorded_answers ||= question.answers.where(author_id: user.id).to_a
    end

    # Reached by an option not yet chosen while the maximum is spent: the question
    # stays on offer at its maximum, so that a choice can still be taken back. Said
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
    #
    # One transaction for the lot, so a typed answer naming several options is in the
    # ballot whole or not at all.
    def record!
      ::Poll::Answer.transaction do
        @question_answers.each do |option|
          answer = question.find_or_initialize_user_answer(user, option)

          answer.save_and_record_voter_participation
        end
      end
    end

    # The choice comes off the ballot the way the page takes it off, the voter
    # participation with it where it was the citizen's last answer in the poll.
    #
    # The question is held open again where no other is: a choice taken back from a
    # question already finished reopens it, and the walk, which reads the recorded
    # answers, would otherwise pass it by with whatever is left. Another question
    # being chosen from keeps its marker — the citizen is still in the middle of it.
    def withdraw
      withdrawn_answer.destroy_and_remove_voter_participation

      if @conversation.open_multiple_question_id.blank?
        @conversation.store_open_multiple_question!(question.id)
      end

      advance
    end

    def withdrawn_answer
      recorded_answers.find { |answer| answer.answer == @question_answers.first.title }
    end

    def advance
      @conversation.store_active_poll!(poll.id)

      ::Whatsapp::Polls::AdvanceBallotService.call(conversation: @conversation, poll: poll)
    end

    def question
      @question ||= @question_answers.first.question
    end

    def projekt_phase
      @projekt_phase ||= question&.poll&.projekt_phase
    end

    def user
      @conversation.user
    end
end
