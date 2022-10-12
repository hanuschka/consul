class Poll::Answer::Stats < Poll::Stats
  alias_method :answer, :resource

  private

    def voters
      participant_user_ids = answer.question.answers.where(answer: answer.title).pluck(:author_id)
      poll = answer.question.poll

      @voters ||= poll.voters.where(user_id: participant_user_ids).select(:user_id)
    end

    def recounts
      poll = answer.question.poll

      @recounts ||= poll.recounts
    end

    def stats_cache(key, &block)
      send "raw_#{key}".to_sym
    end
end
