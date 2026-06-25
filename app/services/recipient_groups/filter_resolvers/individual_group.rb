module RecipientGroups
  module FilterResolvers
    class IndividualGroup < Base
      def emails
        ids = Array(params[:individual_group_value_ids]).map(&:to_i).reject(&:zero?)
        return [] if ids.empty?

        user_ids = UserIndividualGroupValue.where(individual_group_value_id: ids).pluck(:user_id).uniq
        User.actual.where(id: user_ids).pluck(:email).compact.uniq
      end
    end
  end
end
