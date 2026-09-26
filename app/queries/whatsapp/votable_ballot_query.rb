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
  # - a rating scale, whose steps are ordinary options and are offered as pills like
  #   any others, with the portal's own wording for the lowest and the highest step
  #   above them. It records like a `unique` question: one row, replaced.
  # - a weighted vote, asked one choice at a time — how much of the question's
  #   budget that choice carries — because a chat has no way to show a budget being
  #   split across a list. Its options are not a list to pick from, so their number
  #   is not what has to fit; the weight picker is.
  # - a map point, which is the one question answered by something other than a
  #   tap or a sentence: WhatsApp's own location message. It carries no options at
  #   all.
  #
  # What still does not fit, and sends the citizen to the ballot page instead: a
  # scale with more steps than a list holds, a weighted question whose widest
  # picker does not fit one, and — for a question short enough to arrive as bare
  # buttons — two options a button's twenty characters cannot tell apart. Past three
  # rows the message prints the options in full and numbers the pills to match, so
  # there the twenty characters no longer decide anything.
  # One of them anywhere in the poll disqualifies the poll, not the question:
  # a ballot half-answered in a chat and half on the page is not one the citizen
  # meant to cast.
  ANSWERABLE_VOTE_TYPES = [
    "unique", "multiple", "multiple_with_weight", "rating_scale", "map_points", nil
  ].freeze

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

  # How many rows the question's widest send actually carries, which is the other
  # side of the same count: its options, plus the row a multiple question spends on
  # the pill that says the citizen is finished.
  def self.rows_needed(question, options_count)
    return options_count + 1 if question.multiple?

    options_count
  end

  # One question's shape, asked of the poll's every question by the gate below and
  # again by the service that sends one. Public because the two need the same
  # answer and a second copy of these rules is how the gate and the message come to
  # disagree about what can be asked.
  def self.answerable?(question)
    return false if !ANSWERABLE_VOTE_TYPES.include?(question.vote_type)
    return map_points_answerable?(question) if question.map_points?

    options = question.question_answers.to_a

    return false if options.empty?
    return true if free_text_only?(options)
    return weighted_answerable?(question, options) if weighted?(question)
    return false if !tellable_apart?(question, options)

    options.size.between?(MIN_OPTIONS, rows_available(question))
  end

  # Whether the citizen can tell the options apart on the pills, asked only of a
  # question that arrives as buttons. Past three rows WhatsApp puts the options
  # behind its picker — and there the message prints each of them in full and the
  # pills carry the numbers those lines are read by, so two options alike past
  # twenty characters are still two the citizen can choose between. The whole poll
  # used to go to the page for that.
  def self.tellable_apart?(question, options)
    return true if !::Whatsapp.buttons?(rows_needed(question, options.size))

    distinct_labels?(options)
  end

  # A map-point question has nothing to fit into a list and nothing to tell apart —
  # it carries no options at all — so the only thing that can rule it out is an area
  # the portal drew that cannot be tested. Polls::MapPointBoundary needs the GEOS
  # extension for that, and without it a point can be neither accepted nor refused:
  # the question is better left to the page than answered against an area nobody
  # checked.
  def self.map_points_answerable?(question)
    ::Polls::MapPointBoundary.new(question).usable?
  end

  # A weighted question is asked one choice at a time, so however many choices it
  # holds they are never one list — what has to fit a list is the numbers offered
  # beside a single choice. The choices' own labels are not on the buttons either:
  # they are named in the message above the numbers, at full length, so two of them
  # alike past twenty characters is not the problem it is elsewhere.
  def self.weighted_answerable?(question, options)
    return false if options.size < MIN_OPTIONS

    max_weight_steps(question).between?(MIN_OPTIONS, ::Whatsapp::MAX_OFFERED_LIST_ROWS)
  end

  # How many numbers the widest weight picker of a question carries: nothing up to
  # the whole budget, or up to the per-choice cap where the portal set one. The
  # citizen is offered what is still free rather than this, which can only be
  # smaller — so a question whose widest picker fits a list is one every picker of
  # which fits.
  def self.max_weight_steps(question)
    cap = [question.max_votes, question.votation_type&.max_votes_per_answer].compact.min

    cap.to_i + 1
  end

  # Read off the votation type rather than the question: Questionable delegates
  # #multiple?, #map_points?, #rating_scale? and #vote_type and stops there, so
  # #multiple_with_weight? on a question raises rather than answering false.
  def self.weighted?(question)
    question.votation_type&.multiple_with_weight?
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
  #
  # A bare button is the only place that holds: see #tellable_apart? for the case
  # where a number in front of the label answers the question instead.
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
  #
  # The map location is preloaded for the area a map-point question is tested
  # against. It belongs to a handful of questions across the whole portal and to
  # none of the other types, and left out it is one query per map question of every
  # poll this is asked about.
  def self.askable_questions_of(polls)
    ::Poll::Question
      .where(poll_id: polls.map(&:id), contextualize_by_poll_question_id: nil)
      .includes(:votation_type, :map_location, :question_answers)
      .group_by(&:poll_id)
  end

  # Every question of a ballot has to be one a chat can ask, and a ballot with no
  # questions at all is not one either. A question with no options is passed over —
  # that is the heading half of a bundle, which has nothing to ask and nothing to
  # record — except a map-point question, which has no options by its nature and is
  # answered by a position rather than by one of them.
  def self.all_answerable?(questions)
    askable = Array(questions).select { |question| asks_something?(question) }

    return false if askable.empty?

    askable.all? { |question| answerable?(question) }
  end

  # The same reading Polls::BallotTraversalQuery walks by, asked here of the
  # questions the gate has already loaded.
  def self.asks_something?(question)
    question.question_answers.any? || question.map_points?
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
