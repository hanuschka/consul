module RecipientGroups
  module FilterResolvers
    class ProjektSubscribers < Base
      def emails
        return [] if params[:projekt_id].blank?

        user_ids = ProjektSubscription
                     .where(projekt_id: params[:projekt_id], active: true)
                     .pluck(:user_id)

        User.actual.where(id: user_ids).pluck(:email).compact.uniq
      end
    end
  end
end
