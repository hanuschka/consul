class Poll::Question::Stats < Poll::Stats
  alias_method :question, :resource

  private

    def voters
      @voters ||= question.poll.voters.where(user_id: participant_user_ids).select(:user_id)
    end

    def participant_user_ids
      @participant_user_ids ||= question.answers.distinct.pluck(:author_id)
    end

    def recounts
      @recounts ||= question.poll.recounts
    end

    def stats_cache(_key)
      yield
    end
end
