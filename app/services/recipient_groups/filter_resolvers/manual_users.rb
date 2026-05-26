module RecipientGroups
  module FilterResolvers
    class ManualUsers < Base
      def emails
        ids = Array(params[:user_ids]).map(&:to_i).reject(&:zero?)
        return [] if ids.empty?

        User.actual.where(id: ids).pluck(:email).compact.uniq
      end
    end
  end
end
