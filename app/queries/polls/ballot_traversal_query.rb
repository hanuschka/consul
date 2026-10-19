class Polls::BallotTraversalQuery < ApplicationQuery
  # The order a citizen walks a poll's questions in, and where it goes next. One
  # implementation of four rules that used to have two:
  #
  # - the order itself. The root questions the portal configured, template
  #   questions excluded, shuffled per participant where a question asks for it.
  # - contexted clones. A template contextualised by another question is cloned
  #   once per option of it, and only the clone belonging to a chosen option is
  #   asked; the rest are passed over.
  # - branching. An option may name the question that follows it
  #   (Poll::Question::Answer#next_question_id).
  # - termination. An option may end the ballot where it is chosen
  #   (Poll::Question::Answer#terminates_poll).
  #
  # All four lived in app/assets/javascripts/custom/question_wizard.js and nowhere
  # on the server, so the WhatsApp bot had to reimplement them to ask a ballot in a
  # chat — two implementations of rules that decide which questions a citizen is
  # ever shown. Now the page asks this too, a step at a time
  # (Polls::QuestionsController#wizard_next), and the JS renders what it is told
  # rather than working it out from a map.
  #
  # Only a forward branch is honoured, which is the one place this parts company
  # with the page it replaces. The page traversed on taps, so a pair of options
  # pointing back at each other cost a citizen a loop they could see and leave;
  # walked server-side it would be a loop inside a request.
  #
  # What it deliberately does not decide is whether a question is *answered*. The
  # page steps past an unanswered question on purpose — that is what an optional
  # question is — while the chat has to stop at the first one still owed, and a
  # question of a bundle is owed there in its own right. Each consumer reads #path
  # and applies its own reading.
  #
  # A map-point question is on the path like any other even though it carries no
  # options. It was dropped when the option-less case was read as a bundle heading
  # alone, which took it off the page's own wizard as well — the browser's map, which
  # this replaced, was built from every root question the portal configured.
  class Position
    attr_reader :question, :number, :total

    def initialize(question:, number: nil, total: nil)
      @question = question
      @number = number
      @total = total
    end
  end

  # What a traversal reads from the database, loaded for several polls at once by
  # .for_polls and handed to each: the root questions in configured order, the
  # titles this citizen chose keyed by question, and their map points counted by
  # question.
  Preloaded = Struct.new(:roots, :answered_titles, :map_point_counts, keyword_init: true)

  def self.for(poll:, user:, order_seed: nil)
    new(poll: poll, user: user, order_seed: order_seed)
  end

  # One citizen's traversals of several polls, as {poll_id => traversal}, for the
  # lists that ask of every row whether it was answered in full. Asked poll by poll,
  # a traversal loads the ballot's questions and every preload behind them, the
  # citizen's answers and their map points — a fixed handful of queries repeated for
  # each poll they have begun. Here each of those runs once for the whole list.
  #
  # Only for the chat, which seeds a shuffled question by the user's id (#initialize);
  # the page passes a seed of its own and walks one poll at a time.
  def self.for_polls(polls:, user:)
    return {} if polls.blank?

    poll_ids = polls.map(&:id)
    roots = root_questions(::Poll::Question.where(poll_id: poll_ids)).to_a.group_by(&:poll_id)
    poll_ids_by_question = ::Poll::Question.where(poll_id: poll_ids).pluck(:id, :poll_id).to_h
    answered = answered_titles_by_poll(poll_ids_by_question, user)
    map_points = map_point_counts_by_poll(poll_ids_by_question, user)

    polls.to_h do |poll|
      preloaded = Preloaded.new(
        roots: roots.fetch(poll.id, []),
        answered_titles: answered.fetch(poll.id, {}),
        map_point_counts: map_points.fetch(poll.id, {})
      )

      [poll.id, new(poll: poll, user: user, preloaded: preloaded)]
    end
  end

  # The root questions a ballot's steps are built from, read the way
  # PollsController#show reads them so the page and the chat walk one list rather
  # than two that agree by coincidence (#sequence).
  def self.root_questions(questions)
    questions
      .root_questions
      .where(contextualize_by_poll_question_id: nil)
      .with_wizard_associations
      .in_configured_order
  end

  # The same, loaded once per request or job and shared by every traversal of the
  # poll in it. A WhatsApp turn walks one ballot several times — the prompt, the
  # reply, the re-ask — and each walk loaded the same questions, options and
  # translations again. Only the questions are shared: each traversal still reads
  # the citizen's answers itself, so an answer recorded mid-turn is seen by the
  # next walk.
  def self.cached_root_questions(poll)
    ::Current.ballot_root_questions ||= {}
    ::Current.ballot_root_questions[poll.id] ||= root_questions(poll.questions).to_a
  end

  # {poll_id => {question_id => [chosen titles]}} over the questions given, which
  # map to their polls. Keyed per poll the way #answered_titles is keyed per ballot.
  def self.answered_titles_by_poll(poll_ids_by_question, user)
    if user.blank? || poll_ids_by_question.empty?
      return {}
    end

    ::Poll::Answer
      .where(question_id: poll_ids_by_question.keys, author: user)
      .pluck(:question_id, :answer)
      .group_by { |question_id, _| poll_ids_by_question[question_id] }
      .transform_values do |rows|
        rows.group_by(&:first).transform_values { |answers| answers.map(&:last) }
      end
  end

  # {poll_id => {question_id => points placed}}, the same way.
  def self.map_point_counts_by_poll(poll_ids_by_question, user)
    if user.blank? || poll_ids_by_question.empty?
      return {}
    end

    counts =
      ::Poll::Answer::MapPoint
        .joins(:answer)
        .where(poll_answers: { question_id: poll_ids_by_question.keys, author_id: user.id })
        .group("poll_answers.question_id")
        .count

    counts
      .group_by { |question_id, _| poll_ids_by_question[question_id] }
      .transform_values(&:to_h)
  end

  # `order_seed` is what a question asking to be shuffled is shuffled by, and it has
  # to be the caller's rather than derived here: PollsHelper#poll_participant_order_seed
  # reads `session[:guest_user_id]` first, which is a "guest_<uuid>" string and not
  # the guest User's id at all — seeded from the id instead, the page would order the
  # steps one way and the questions rendered into it another. The chat has no session
  # and cannot be voted in by a guest, so there the id is the seed.
  #
  # `preloaded` is what .for_polls loaded for this poll alongside the others; left
  # out, the traversal loads its own.
  def initialize(poll:, user:, order_seed: nil, preloaded: nil)
    @poll = poll
    @user = user
    @order_seed = order_seed.presence || user&.id
    @preloaded = preloaded
  end

  # The root questions this citizen actually walks, in order: hidden clones
  # dropped, branches followed, and nothing after an option that ends the ballot.
  # Recomputed from the recorded answers on every call, which is what makes it
  # correct for a ballot resumed days later — the taps that built the page's own
  # state happened in a browser that has since been closed.
  def path
    @path ||= begin
      walked = []
      index = 0

      while index < sequence.size
        question = sequence[index]

        if hidden?(question)
          index += 1
          next
        end

        walked << question
        chosen = chosen_options(question)

        break if chosen.any?(&:terminates_poll?)

        index = branch_index(chosen, after: index) || index + 1
      end

      walked
    end
  end

  # The step after this one, which is what the page asks for. Nil where the ballot
  # ends here — the last question, or one whose chosen answer terminates it — and
  # nil for a question that is not on this citizen's path at all, which is a stale
  # browser asking about a clone they no longer qualify for.
  def next_after(question)
    index = path.index { |candidate| candidate.id == question.id }

    return if index.blank?

    path[index + 1]
  end

  def next_after?(question)
    next_after(question).present?
  end

  # The first question still owed, for a ballot asked one message at a time. Every
  # question counts here, a bundle's nested sub-questions included: the page renders
  # those under one heading, but a chat can only ask one thing at a time and each of
  # them is a question in its own right.
  #
  # `still_choosing_question_id` is the one thing the recorded answers cannot say: a
  # multiple-choice question is not finished by its first answer, so while the
  # citizen is picking from one it has to be read as unanswered however many choices
  # are already stored.
  #
  # `declined_question_ids` are the questions they have said they would rather not
  # answer. A skipped free-text question has no answer row and never will, so
  # without them the walk would hand it back on every message.
  def first_owed(still_choosing_question_id: nil, declined_question_ids: [])
    return if @user.blank?

    still_choosing = still_choosing_question_id.presence&.to_i
    declined = Array(declined_question_ids).map(&:to_i)

    asked = 0

    expanded_path.each do |question|
      asked += 1

      next if declined.include?(question.id)
      next if answered?(question) && question.id != still_choosing

      return Position.new(question: question, number: asked, total: total)
    end

    nil
  end

  # Whether this citizen has nothing left to answer in the poll — the reading that
  # tells a ballot already taken part in from one still to begin, and the one place
  # that decides it, so a chat offering the vote and a chat answering the tap cannot
  # disagree about who has voted.
  #
  # Deliberately blind to the conversation's own markers, where #first_owed takes both.
  # A question the citizen declined has no answer row and never will, so counting it as
  # settled would read a ballot walked away from half-way as one finished. Left out, it
  # is still owed and the ballot resumes at it, which is what a partly answered ballot
  # has to do.
  #
  # A citizen with no account has answered nothing rather than everything, which
  # #first_owed's own blank for a missing user would otherwise say the opposite of.
  def nothing_owed?
    return false if @user.blank?

    first_owed.blank?
  end

  # Every question on this citizen's path still without a full answer, in the order
  # they are asked. Blind to the conversation's markers for the reason #nothing_owed?
  # is: a question they skipped is still owed, and listed here.
  def owed_questions
    return [] if @user.blank?

    expanded_path.reject { |question| answered?(question) }
  end

  # How many questions the ballot holds, for the line that tells a citizen how much
  # of it is left. Counted over the whole sequence rather than the path, and in slots
  # — a template's set of contexted clones is one, since exactly one of them is ever
  # asked. Branching can still make the real count smaller, so the number can turn
  # out generous but never mean, and a total that grows while a citizen works
  # through a ballot is worse than one that is approximate.
  def total
    @total ||= expanded_sequence
      .map { |question| question.contexted_clone_of_poll_question_id || question.id }
      .uniq.size
  end

  # Every question this citizen is asked, in the order they are asked it — the path
  # with each bundle's sub-questions after their heading, which is how a chat walks
  # it one message at a time.
  def expanded_path
    @expanded_path ||= expanded(path)
  end

  # How many points this citizen has placed on a map question, read from the one
  # count the walk already holds for the whole ballot.
  def map_points_placed(question)
    map_point_counts.fetch(question.id, 0)
  end

  private

    # Every root question in the order the citizen meets it, read the way
    # PollsController#show reads them so the page and the chat walk one list rather
    # than two that agree by coincidence.
    #
    # The templates are left out because they are never asked: a template carries
    # contextualize_by_poll_question_id and exists to be cloned once per answer of
    # the question it depends on, and the clones carry a null there like any
    # ordinary question.
    #
    def sequence
      @sequence ||= participant_ordered_roots.select { |question| step?(question) }
    end

    # A root is a step when it asks something itself or heads a bundle whose
    # sub-questions do. The heading carries no options of its own, and reading
    # that alone as "asks nothing" took the whole bundle off the page's wizard
    # and out of the chat.
    def step?(root)
      asks_something?(root) || root.nested_questions.any? { |nested| asks_something?(nested) }
    end

    def participant_ordered_roots
      roots = @preloaded&.roots || self.class.cached_root_questions(@poll)

      @poll.questions_in_participant_order(roots, @order_seed)
    end

    # A root followed by its own nested sub-questions, which is the granularity a
    # chat asks at, with anything that asks nothing dropped (#asks_something?).
    def expanded(roots)
      roots.flat_map { |root| [root] + root.nested_questions.to_a }
        .select { |question| asks_something?(question) }
    end

    def expanded_sequence
      @expanded_sequence ||= expanded(sequence)
    end

    # Whether there is anything here to put to the citizen. A question with no
    # options is the heading half of a bundle, which has nothing to ask and nothing
    # to record — except a map-point question, which never has options at all: what
    # it asks for is a position, and what it records is Poll::Answer::MapPoint rows
    # under an answer whose own `answer` column stays null.
    def asks_something?(question)
      question.question_answers.any? || question.map_points?
    end

    # Whether this citizen has answered, which for every question but one is whether
    # any of its options carries their name. A map-point question is answered by the
    # points it asked for, and it is answered only once it has all of them: the
    # portal's page keeps its map open until the last one is placed, and a chat that
    # moved on after the first would take one point for a question that asked for
    # three.
    def answered?(question)
      return map_points_placed(question) >= question.max_map_points if question.map_points?

      chosen_options(question).any?
    end

    # One query for every map question of the ballot, keyed the way #answered_titles
    # is: a count asked per question would be one round trip per step of a walk that
    # already costs a fixed handful.
    def map_point_counts
      return @map_point_counts if defined?(@map_point_counts)

      @map_point_counts =
        if @user.blank?
          {}
        elsif @preloaded.present?
          @preloaded.map_point_counts
        else
          ::Poll::Answer::MapPoint
            .joins(:answer)
            .where(poll_answers: { question_id: @poll.question_ids, author_id: @user.id })
            .group("poll_answers.question_id")
            .count
        end
    end

    # A contexted clone belongs to one option of the question that contextualises
    # it, and is asked only if that option is among the answers actually given.
    def hidden?(question)
      context_answer = question.context

      return false if context_answer.blank?

      !answered_titles.fetch(context_answer.question_id, []).include?(context_answer.title)
    end

    def chosen_options(question)
      titles = answered_titles.fetch(question.id, [])

      return [] if titles.empty?

      question.question_answers.select { |option| titles.include?(option.title) }
    end

    # The first chosen option that names a question ahead of this one. Checked
    # against the sequence rather than trusted from the column: a branch target may
    # have been hidden, may be a nested question of a different root, or may have
    # been deleted since the answer was recorded.
    def branch_index(chosen, after:)
      chosen.filter_map(&:next_question_id).each do |target_id|
        index = sequence.index { |question| question.id == target_id }

        next if index.blank? || index <= after
        next if hidden?(sequence[index])

        return index
      end

      nil
    end

    # One query for the whole ballot, keyed by question. Asked across every question
    # of the poll rather than only the sequence, because the answer that reveals a
    # contexted clone is read off the question that contextualises it and being
    # certain that one is in the list costs nothing here.
    def answered_titles
      return @answered_titles if defined?(@answered_titles)

      @answered_titles =
        if @user.blank?
          {}
        elsif @preloaded.present?
          @preloaded.answered_titles
        else
          ::Poll::Answer
            .where(question_id: @poll.question_ids, author: @user)
            .pluck(:question_id, :answer)
            .group_by(&:first)
            .transform_values { |rows| rows.map(&:last) }
        end
    end
end
