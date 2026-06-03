module RecipientGroups
  module FilterResolvers
    class Plz < Base
      def emails
        list = Array(params[:plz_list]).map(&:to_s).reject(&:blank?).map(&:to_i)
        return [] if list.empty?

        User.actual.where(plz: list).pluck(:email).compact.uniq
      end
    end
  end
end
