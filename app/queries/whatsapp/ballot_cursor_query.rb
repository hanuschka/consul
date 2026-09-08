class Whatsapp::BallotCursorQuery < ApplicationQuery
  # The next question of a ballot the citizen still owes an answer to, or nothing
  # when the ballot is finished. There is no cursor written down anywhere: the
  # answers already recorded *are* the cursor, so a ballot resumes correctly after
  # a login, a week's silence, or a question asked in the middle of it, and a poll
  # that closes in between leaves no stale position behind to be resumed from.
  #
  # It walks the same order and obeys the same two branching rules as the page's
  # wizard, which are implemented in app/assets/javascripts/custom/question_wizard.js
  # and nowhere on the server:
  #
  # - a contexted clone is asked only when the answer it belongs to was actually
  #   given. The clones of one template are one question per option of the
  #   question that contextualises it, and all but the chosen one are passed over.
  # - an option may name the question that follows it (next_question_id), and one
  #   may end the ballot outright (terminates_poll).
  #
  # Only a forward branch is honoured, which is where the two part company. The
  # page traverses on taps, so a pair of options pointing back at each other costs
  # a citizen a loop they can see and leave; here it would be a loop with a held
  # advisory lock in it, so a branch that does not advance is read as no branch.
  class Position
    attr_reader :question, :number, :total

    def initialize(question:, number: nil, total: nil)
      @question = question
      @number = number
      @total = total
    end
  end

  def self.for(poll:, user:, still_choosing_question_id: nil, declined_question_ids: [])
    new(
      poll: poll,
      user: user,
      still_choosing_question_id: still_choosing_question_id,
      declined_question_ids: declined_question_ids
    ).call
  end

  # `still_choosing_question_id` is the one thing the recorded answers cannot say:
  # a multiple-choice question is not finished by its first answer, so while the
  # citizen is picking from one it has to be read as unanswered however many
  # choices are already stored. The conversation carries the id
  # (Whatsapp::Conversation#open_multiple_question_id) and drops it the moment the
  # question is settled — by the citizen saying they are done, or by their last
  # allowed choice being spent.
  # `declined_question_ids` are the questions the citizen has said they would rather
  # not answer. A skipped free-text question has no answer row and never will, so
  # without them the walk would find it unanswered and hand it back on every message.
  def initialize(poll:, user:, still_choosing_question_id: nil, declined_question_ids: [])
    @poll = poll
    @user = user
    @still_choosing_question_id = still_choosing_question_id
    @declined_question_ids = Array(declined_question_ids).map(&:to_i)
  end

  # The question and where it sits, for the line that tells the citizen how much of
  # the ballot is left. The total counts the slots the ballot holds rather than the
  # questions that will actually be asked: branching is only knowable as the answers
  # arrive, so the number can turn out generous but never mean — and a total that
  # grows while a citizen works through a ballot is worse than one that is
  # approximate.
  def call
    return if @user.blank?

    index = 0
    asked = 0

    while index < sequence.size
      question = sequence[index]

      if hidden?(question)
        index += 1
        next
      end

      asked += 1
      chosen = chosen_options(question)

      return position_of(question, asked) if unanswered?(question, chosen)
      return if chosen.any?(&:terminates_poll?)

      index = branch_index(chosen, after: index) || index + 1
    end

    nil
  end

  private

    def position_of(question, number)
      Position.new(question: question, number: number, total: askable_total)
    end

    # Every question in the order the citizen meets it: the root questions as the
    # portal ordered them and this participant sees them, each followed by its own
    # nested sub-questions.
    #
    # The roots are read the way PollsController#show reads them, template
    # questions excluded, so the chat and the page walk one list rather than two
    # that agree by coincidence. The seed is the citizen's user id, which is what
    # the page's seed reduces to for anyone signed in — and a ballot cannot be cast
    # without an account.
    def sequence
      @sequence ||= flattened(participant_ordered_roots)
    end

    def participant_ordered_roots
      roots = @poll.questions.root_questions
        .where(contextualize_by_poll_question_id: nil)
        .with_wizard_associations
        .in_configured_order

      @poll.questions_in_participant_order(roots, @user.id)
    end

    def flattened(roots)
      roots.flat_map { |root| [root] + root.nested_questions.to_a }
        .reject { |question| question.question_answers.empty? }
    end

    # Counted in slots, where a template's whole set of contexted clones is one:
    # exactly one of them is ever asked, and counting them individually would have
    # the total climb by one every time a clone was revealed.
    def askable_total
      @askable_total ||= sequence
        .map { |question| question.contexted_clone_of_poll_question_id || question.id }
        .uniq.size
    end

    # A contexted clone belongs to one option of the question that contextualises
    # it, and is asked only if that option is among the answers actually given.
    # Read from the recorded answers rather than from a set built up while walking,
    # because the walk starts fresh on every message and the taps that built the
    # page's set happened turns ago.
    def hidden?(question)
      context_answer = question.context

      return false if context_answer.blank?

      !answered_titles.fetch(context_answer.question_id, []).include?(context_answer.title)
    end

    # A declined question is walked past but still counted, so the numbering a citizen
    # reads does not shift under them halfway through a ballot.
    def unanswered?(question, chosen)
      return false if @declined_question_ids.include?(question.id)

      chosen.empty? || still_choosing?(question)
    end

    def still_choosing?(question)
      @still_choosing_question_id.present? && question.id == @still_choosing_question_id.to_i
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
      @answered_titles ||= ::Poll::Answer
        .where(question_id: @poll.question_ids, author: @user)
        .pluck(:question_id, :answer)
        .group_by(&:first)
        .transform_values { |rows| rows.map(&:last) }
    end
end
