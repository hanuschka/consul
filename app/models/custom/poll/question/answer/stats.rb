class Poll::Question::Answer::Stats < Poll::Stats
  alias_method :question_answer, :resource

  private

    def voters
      poll = question_answer.question.poll

      @voters ||= poll.voters.where(user_id: participant_user_ids).select(:user_id)
    end

    def participant_user_ids
      if question_answer.open_answer?
        question_answer.question.answers.where(answer: question_answer.title).where.not(open_answer_text: ["", nil]).pluck(:author_id)
      else
        question_answer.question.answers.where(answer: question_answer.title).pluck(:author_id)
      end
    end

    def recounts
      poll = question_answer.question.poll

      @recounts ||= poll.recounts
    end

    def stats_cache(key, &block)
      send "raw_#{key}".to_sym
    end
end
