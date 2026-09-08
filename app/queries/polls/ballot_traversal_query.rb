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

  def self.for(poll:, user:, order_seed: nil)
    new(poll: poll, user: user, order_seed: order_seed)
  end

  # `order_seed` is what a question asking to be shuffled is shuffled by, and it has
  # to be the caller's rather than derived here: PollsHelper#poll_participant_order_seed
  # reads `session[:guest_user_id]` first, which is a "guest_<uuid>" string and not
  # the guest User's id at all — seeded from the id instead, the page would order the
  # steps one way and the questions rendered into it another. The chat has no session
  # and cannot be voted in by a guest, so there the id is the seed.
  def initialize(poll:, user:, order_seed: nil)
    @poll = poll
    @user = user
    @order_seed = order_seed.presence || user&.id
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
      @sequence ||= participant_ordered_roots.select { |question| asks_something?(question) }
    end

    def participant_ordered_roots
      roots = @poll.questions.root_questions
        .where(contextualize_by_poll_question_id: nil)
        .with_wizard_associations
        .in_configured_order

      @poll.questions_in_participant_order(roots, @order_seed)
    end

    # A root followed by its own nested sub-questions, which is the granularity a
    # chat asks at, with anything that asks nothing dropped (#asks_something?).
    def expanded(roots)
      roots.flat_map { |root| [root] + root.nested_questions.to_a }
        .select { |question| asks_something?(question) }
    end

    def expanded_path
      @expanded_path ||= expanded(path)
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

    def map_points_placed(question)
      map_point_counts.fetch(question.id, 0)
    end

    # One query for every map question of the ballot, keyed the way #answered_titles
    # is: a count asked per question would be one round trip per step of a walk that
    # already costs a fixed handful.
    def map_point_counts
      return @map_point_counts if defined?(@map_point_counts)

      @map_point_counts =
        if @user.blank?
          {}
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
        else
          ::Poll::Answer
            .where(question_id: @poll.question_ids, author: @user)
            .pluck(:question_id, :answer)
            .group_by(&:first)
            .transform_values { |rows| rows.map(&:last) }
        end
    end
end
