class Whatsapp::Polls::BallotSummaryQuery < ApplicationQuery
  # What a citizen answered in a ballot, question by question in the order they were
  # asked it, for the close of a ballot in a chat. Asked one message at a time, a
  # ballot otherwise ends without its answers ever being in front of the citizen
  # together, where the page shows them the whole form they filled in.
  #
  # The answers are the poll's own wording, cut where one runs long: a summary in a
  # paraphrase of the options is a summary of something the citizen did not answer.
  # A question they passed over is left out, because nothing of theirs stands there.
  Entry = Struct.new(:question, :answers, :map_points, keyword_init: true)

  ANSWER_LENGTH = 160

  def initialize(poll:, user:)
    @poll = poll
    @user = user
  end

  def call
    return [] if @user.blank?

    questions = traversal.expanded_path
    rows = answer_rows(questions)

    questions.filter_map { |question| entry(question, rows.fetch(question.id, [])) }
  end

  private

    def traversal
      @traversal ||= ::Polls::BallotTraversalQuery.for(poll: @poll, user: @user)
    end

    # One query for the whole ballot, each question's choices in the order they were
    # made. A map question's own row carries no answer — its points are counted by
    # the walk instead (#entry).
    def answer_rows(questions)
      ::Poll::Answer
        .where(question_id: questions.map(&:id), author: @user)
        .where.not(answer: nil)
        .order(:id)
        .pluck(:question_id, :answer, :open_answer_text, :answer_weight)
        .group_by(&:first)
    end

    def entry(question, rows)
      if question.map_points?
        placed = traversal.map_points_placed(question)

        return if placed.zero?

        return Entry.new(question: question, answers: [], map_points: placed)
      end

      return if rows.empty?

      Entry.new(
        question: question,
        answers: rows.map { |row| answer_text(question, row) },
        map_points: 0
      )
    end

    # The citizen's own words where the option stood for them, and the points beside
    # the option where the question was weighted.
    def answer_text(question, row)
      _question_id, title, open_answer_text, weight = row

      text =
        if ::Whatsapp::VotableBallotQuery.weighted?(question)
          "#{title}: #{weight}"
        else
          open_answer_text.presence || title
        end

      text.to_s.squish.truncate(ANSWER_LENGTH)
    end
end
