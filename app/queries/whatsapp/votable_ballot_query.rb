class Whatsapp::VotableBallotQuery < ApplicationQuery
  # The poll behind a voting phase when it is one a chat can carry from the first
  # question to the last, or nothing. Answers the whole ballot rather than one
  # question of it, because that is the unit the citizen commits to: a poll checked
  # question by question could be begun here and abandoned half-way, with the
  # answers already given recorded and the rest not, which is a ballot nobody meant
  # to cast.
  #
  # What fits:
  #
  # - `unique`, which is one choice out of several, and `multiple`, which is
  #   several out of them up to the maximum the portal set. A nil votation type is
  #   the first of those — Questionable#find_by_attributes reads nil and "unique"
  #   as one case, so a question with no type recorded stores an answer exactly as
  #   a unique one does.
  # - free text, which is an option flagged open_answer. It is asked as a question
  #   to type rather than a pill to tap, and a question may carry one beside its
  #   choices as the portal's "something else" line.
  # - between two options and as many as a WhatsApp list holds, counting the extra
  #   row a `multiple` question spends on saying it is finished. Below two there is
  #   nothing to choose; above, the list cannot hold them and the portal page is
  #   where the whole question is legible anyway.
  #
  # What does not, and sends the citizen to the ballot page instead: rating scales,
  # weighted votes and map points. All three are answered by a control a chat has
  # no equivalent of — a slider, a budget split across options, a pin on a map —
  # and one of them anywhere in the poll disqualifies the poll, not the question.
  ANSWERABLE_VOTE_TYPES = ["unique", "multiple", nil].freeze

  MIN_OPTIONS = 2

  def self.for(projekt_phase)
    new(projekt_phase: projekt_phase).call
  end

  # The same question asked of many polls at once, for the tool that lists what is
  # open. It costs the same handful of queries whether the page holds one poll or
  # nine, where asking #for per row cost that handful each: which poll is a phase's
  # ballot comes back for every phase in one query, and the questions of every
  # candidate come back in one pass.
  def self.votable_poll_ids(polls)
    ballots = ::Polls::PhaseBallotQuery.by_phase(polls.map(&:projekt_phase_id))
    candidates = polls.select { |poll| candidate?(poll, ballots) }

    return [] if candidates.empty?

    questions_by_poll = askable_questions_of(candidates)

    candidates.filter_map { |poll| poll.id if all_answerable?(questions_by_poll[poll.id]) }
  end

  # The options as the citizen will read them: the order the portal set, shuffled
  # per participant where the question asks for it, and the open one last wherever
  # there is one. Its own method because the tap that follows resolves an option by
  # its id and then stores its *title* — Poll::Answer records the answer as text —
  # so the two sides have to be reading the same rows.
  #
  # The seed is the citizen's own user id, which is what PollsHelper's seed reduces
  # to for anyone signed in. A ballot cannot be cast without an account, so the
  # guest and session branches of that helper cannot apply here, and reusing the id
  # is what makes the chat show the same order as the page.
  def self.options(question, seed:)
    ordered = question.question_answers.order(:given_order, :id)

    question.answers_in_participant_order(ordered, seed)
  end

  # How many list rows one question needs at its widest. A `multiple` question
  # spends one on the pill that says the citizen is finished, and the widest it
  # gets is its first send, before any choice has dropped out of the list.
  def self.rows_available(question)
    return ::Whatsapp::MAX_OFFERED_LIST_ROWS - 1 if question.multiple?

    ::Whatsapp::MAX_OFFERED_LIST_ROWS
  end

  # One question's shape, asked of the poll's every question by the gate below and
  # again by the service that sends one. Public because the two need the same
  # answer and a second copy of these rules is how the gate and the message come to
  # disagree about what can be asked.
  def self.answerable?(question)
    return false if !ANSWERABLE_VOTE_TYPES.include?(question.vote_type)

    options = question.question_answers.to_a

    return false if options.empty?
    return true if free_text_only?(options)
    return false if !distinct_labels?(options)

    options.size.between?(MIN_OPTIONS, rows_available(question))
  end

  # A question whose only option is the open one: nothing to choose between, so it
  # is asked as a sentence to write rather than as a single pointless pill. The
  # two-option floor does not apply to it, which is why it is answered before the
  # floor is checked.
  def self.free_text_only?(options)
    options.size == 1 && options.first.open_answer?
  end

  # Every option has to still be its own option once it is on a button. WhatsApp
  # allows twenty characters on a title, and two options whose difference lies past
  # that arrive as the same word twice — a ballot the citizen cannot answer,
  # because there is nothing on either pill to say which is which. The vote itself
  # is unaffected either way, since the tap carries the option's id; what is at
  # stake is whether the citizen can tell what they are voting for.
  def self.distinct_labels?(options)
    labels = options.filter_map { |option| ::Whatsapp::AssistantActions.truncated(option.title) }

    labels.size == options.size && labels.uniq.size == options.size
  end

  # Whether a poll could be one at all: its phase running, and the poll being that
  # phase's ballot. Everything before its questions are looked at.
  def self.candidate?(poll, ballots)
    projekt_phase = poll.projekt_phase

    projekt_phase.current? && ballots[poll.projekt_phase_id] == poll
  end

  # The options are preloaded without naming their translations:
  # Poll::Question::Answer carries a default scope that includes them, so asking
  # again here would only repeat it.
  def self.askable_questions_of(polls)
    ::Poll::Question
      .where(poll_id: polls.map(&:id), contextualize_by_poll_question_id: nil)
      .includes(:votation_type, :question_answers)
      .group_by(&:poll_id)
  end

  # Every question of a ballot has to be one a chat can ask, and a ballot with no
  # questions at all is not one either. A question with no options is passed over —
  # that is the heading half of a bundle, which has nothing to ask and nothing to
  # record.
  def self.all_answerable?(questions)
    askable = Array(questions).reject { |question| question.question_answers.empty? }

    return false if askable.empty?

    askable.all? { |question| answerable?(question) }
  end

  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def call
    return if !@projekt_phase.current?

    poll = ballot

    return if poll.blank?

    return if !self.class.all_answerable?(askable_questions(poll))

    poll
  end

  private

    # Which poll a voting phase's ballot is belongs to Polls::PhaseBallotQuery,
    # which also carries why it cannot be ProjektPhase::VotingPhase#poll.
    #
    # The phase is asked for its own currency rather than the poll being run
    # through Poll.current, which is the same question in SQL and answers it
    # differently: the scope compares `projekt_phases.start_date <= today <=
    # end_date` with no regard for nulls, where ProjektPhase#current? reads a null
    # date as "no bound". Half the portal's voting phases have one — an open-ended
    # vote is an ordinary thing to run — and every one of them is excluded by the
    # scope while being open in every other part of the app.
    def ballot
      ::Polls::PhaseBallotQuery.for(@projekt_phase)
    end

    # Every question the citizen owes an answer to, nested ones included: a
    # sub-question of a bundle is still a question, and the chat asks each of them
    # its own turn rather than rendering them under one heading the way the page
    # does.
    #
    # The contextualisation templates are left out because they are never asked.
    # A template carries contextualize_by_poll_question_id and exists to be cloned
    # once per answer of the question it depends on; the clones are what the
    # citizen sees, and they carry a null there like any ordinary question.
    def askable_questions(poll)
      self.class.askable_questions_of([poll])[poll.id]
    end
end
