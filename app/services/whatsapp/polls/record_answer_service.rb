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
  # is it.
  def initialize(conversation:, question_answer:)
    @conversation = conversation
    @question_answer = question_answer
  end

  def call
    return false if user.blank?
    return false if !votable?

    record!
    confirm

    true
  end

  private

    def votable?
      projekt_phase.present? &&
        ::Whatsapp::VotableQuestionQuery.for(projekt_phase) == question &&
        projekt_phase.permission_problem(user).blank?
    end

    # The title read off the record rather than off the button the citizen tapped:
    # Poll::Answer stores the answer as text, and the button carries at most twenty
    # characters of it. Storing what the button said would file a vote under a cut
    # phrase that matches no option the poll has.
    def record!
      answer = question.find_or_initialize_user_answer(user, @question_answer.title)

      answer.save_and_record_voter_participation
    end

    def confirm
      ::Whatsapp::Send.locale_text(
        account: @conversation.whatsapp_account,
        body: I18n.t(
          "whatsapp.bot.poll.recorded",
          poll: question.poll.name, answer: @question_answer.title
        )
      )
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
