class Polls::AnswerAllowanceQuery < ApplicationQuery
  # Whether one particular answer may be recorded for one citizen: the maximum a
  # question allows, in the one place that decides it.
  #
  # It was decided in four before — Polls::Questions::AnswerFormComponent and
  # AnswersComponent each disabled a button by their own reading of it,
  # OpenAnswerComponent gated the free-text box by a third, and the WhatsApp bot
  # counted for itself — and in none of them was it enforced. Polls::QuestionsController#answer
  # recorded whatever it was handed, so the cap held only for as long as a citizen
  # used the buttons the page had rendered: a repeated POST, a stale form, or any
  # second client wrote past it silently, and the extra rows are indistinguishable
  # from votes afterwards.
  #
  # The two questions with a maximum:
  #
  # - `multiple` allows up to max_votes options, one row each. An option already
  #   chosen costs nothing to choose again — the write finds the row it wrote
  #   before — so it is never what the cap refuses.
  # - `multiple_with_weight` allows max_votes of weight to be split across the
  #   options, and at most max_votes_per_answer of it on any one.
  #
  # `unique` and `rating_scale` replace whatever stands rather than adding to it, so
  # there is nothing to run out of. Map points have their own maximum, enforced
  # where they are added (Polls::QuestionsController#add_map_point) against a lock,
  # because each one is a row rather than a replacement.
  #
  # `recorded_answers` is the citizen's Poll::Answer rows for this question where
  # the caller already has them, which every view does: a page asking per option
  # without it would count the same rows once per button.
  def self.call(question:, user:, title:, weight: 1, recorded_answers: nil)
    new(
      question: question, user: user, title: title,
      weight: weight, recorded_answers: recorded_answers
    ).call
  end

  # How much weight is still free for one option of a weighted question, which is
  # what the selector beside it offers. Its own entry point because a number and a
  # yes-or-no are two different answers, and the number is only ever asked of the
  # one vote type that has weights.
  def self.remaining_weight(question:, user:, title:, recorded_answers: nil)
    new(
      question: question, user: user, title: title, recorded_answers: recorded_answers
    ).remaining_weight
  end

  def initialize(question:, user:, title:, weight: 1, recorded_answers: nil)
    @question = question
    @user = user
    @title = title
    @weight = weight.to_i
    @recorded_answers = recorded_answers
  end

  def call
    return false if @user.blank?
    return false if @question.map_points?
    return remaining_weight >= @weight if weighted?

    return true if !@question.multiple?
    return true if chosen_titles.include?(@title)

    chosen_titles.size < @question.max_votes
  end

  def remaining_weight
    return 0 if @user.blank?

    free = @question.max_votes - spent_weight + own_weight

    [free, @question.votation_type&.max_votes_per_answer].compact.min
  end

  private

    # Read off the votation type rather than the question: Questionable delegates
    # #multiple?, #map_points?, #rating_scale? and #vote_type and stops there, so
    # #multiple_with_weight? on a question raises rather than answering false.
    def weighted?
      @question.votation_type&.multiple_with_weight?
    end

    def recorded_answers
      @recorded_answers ||= @question.answers.where(author_id: @user.id).to_a
    end

    def chosen_titles
      @chosen_titles ||= recorded_answers.map(&:answer)
    end

    def spent_weight
      recorded_answers.sum { |answer| answer.answer_weight.to_i }
    end

    # The weight already on this option comes back into what is free for it, so a
    # citizen changing three votes to two is offered three to choose from rather
    # than the nothing that is left once their own three are counted against them.
    def own_weight
      own = recorded_answers.find { |answer| answer.answer == @title }

      own.present? ? own.answer_weight.to_i : 0
    end
end
