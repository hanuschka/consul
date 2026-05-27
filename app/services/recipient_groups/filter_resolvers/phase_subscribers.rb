module RecipientGroups
  module FilterResolvers
    class PhaseSubscribers < Base
      def emails
        user_ids =
          if params[:projekt_phase_id].present?
            ProjektPhaseSubscription.where(projekt_phase_id: params[:projekt_phase_id]).pluck(:user_id)
          elsif params[:projekt_id].present?
            phase_ids = ProjektPhase.where(projekt_id: params[:projekt_id]).pluck(:id)
            ProjektPhaseSubscription.where(projekt_phase_id: phase_ids).pluck(:user_id)
          else
            []
          end

        User.actual.where(id: user_ids).pluck(:email).compact.uniq
      end
    end
  end
end
