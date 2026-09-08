class Whatsapp::VotableQuestionQuery < ApplicationQuery
  # The one poll question a voting phase can put in front of a citizen as buttons,
  # or nothing. A chat holds one question at a time and answers it with pills, so
  # what it can carry is a narrow shape — and the narrowness is the point: a citizen
  # who starts voting in the chat must be able to finish there. A poll that only
  # half fits is sent to the portal whole rather than begun here and abandoned
  # part-way, with the answers already given recorded and the rest not.
  #
  # What fits:
  #
  # - one poll on the phase, and one question in it, with no nested follow-ups. A
  #   follow-up that depends on the answer just given is a second turn this has no
  #   way to ask, and half the portal's questions are one.
  # - `unique`, which is one choice out of several. A nil votation type is the same
  #   thing — Questionable#find_by_attributes reads the two as one case, so a
  #   question with no type recorded stores an answer exactly as a unique one does.
  # - no open answer, which is free text rather than a choice.
  # - between two options and MAX_OFFERED_LIST_ROWS of them. Below two there is
  #   nothing to choose; above, the list cannot hold them and the portal is where
  #   the whole question is legible anyway.
  UNIQUE_VOTE_TYPES = ["unique", nil].freeze

  MIN_OPTIONS = 2

  def self.for(projekt_phase)
    new(projekt_phase: projekt_phase).call
  end

  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def call
    return if !@projekt_phase.is_a?(ProjektPhase::VotingPhase)

    poll = single_current_poll

    return if poll.blank?

    question = single_question(poll)

    return if question.blank?
    return if !answerable_shape?(question)

    question
  end

  # The options as the citizen will read them, in the order the portal set. Their
  # own method because the tap that follows resolves an option by its id and then
  # stores its *title* — Poll::Answer records the answer as text — so the two sides
  # have to be reading the same rows.
  def self.options(question)
    question.question_answers.includes(:translations).order(:given_order, :id)
  end

  private

    # One published poll, and only while the phase is running. A phase with several is
    # a phase whose question is "which of these", which is the selection step this
    # exists to avoid — and the portal page asks it better than a chat can.
    #
    # The phase is asked for its own currency rather than the poll being run through
    # Poll.current, which is the same question in SQL and answers it differently: the
    # scope compares `projekt_phases.start_date <= today <= end_date` with no regard
    # for nulls, where ProjektPhase#current? reads a null date as "no bound". Half the
    # portal's voting phases have one — an open-ended vote is an ordinary thing to run
    # — and every one of them is excluded by the scope while being open in every other
    # part of the app.
    def single_current_poll
      return if !@projekt_phase.current?

      polls = Poll.where(projekt_phase_id: @projekt_phase.id).published.limit(2).to_a

      return if polls.size != 1

      polls.first
    end

    # Counted rather than loaded, and counted across every question of the poll
    # rather than only the root ones: a nested follow-up is still a question the
    # citizen owes an answer to, and a poll that holds one cannot be finished here.
    def single_question(poll)
      questions = Poll::Question.where(poll_id: poll.id).limit(2).to_a

      return if questions.size != 1

      questions.first
    end

    def answerable_shape?(question)
      return false if !UNIQUE_VOTE_TYPES.include?(question.vote_type)
      return false if question.open_question_answer.present?

      options = self.class.options(question)

      options.size.between?(MIN_OPTIONS, ::Whatsapp::MAX_OFFERED_LIST_ROWS) &&
        distinct_labels?(options)
    end

    # Every option has to still be its own option once it is on a button. WhatsApp
    # allows twenty characters on a title, and two options whose difference lies past
    # that arrive as the same word twice — a ballot the citizen cannot answer, because
    # there is nothing on either pill to say which is which. The vote itself is
    # unaffected either way, since the tap carries the option's id; what is at stake is
    # whether the citizen can tell what they are voting for.
    def distinct_labels?(options)
      labels = options.filter_map { |option| ::Whatsapp::AssistantActions.truncated(option.title) }

      labels.size == options.size && labels.uniq.size == options.size
    end
end
