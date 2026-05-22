module RecipientGroups
  module FilterResolvers
    class VotingParticipants < Base
      def emails
        return [] if params[:projekt_phase_id].blank?

        poll_ids = Poll.where(projekt_phase_id: params[:projekt_phase_id]).pluck(:id)
        user_ids = Poll::Voter.where(poll_id: poll_ids).pluck(:user_id).uniq

        User.actual.where(id: user_ids).pluck(:email).compact.uniq
      end
    end
  end
end
